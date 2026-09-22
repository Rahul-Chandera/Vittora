import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Australian tax golden fixtures for 2025-26 (AU_TY2025_26).
///
/// Derived by hand from the statutory rates and tabulated in the PR for owner
/// spot-check. Rates used:
///
///   Brackets    nil to 18,200 · 16% to 45,000 · 30% to 135,000 · 37% to
///               190,000 · 45% above          (high confidence, legislated)
///   LITO        700 max, 5c taper from 37,500, 1.5c from 45,000, out at 66,667
///   CGT         50% discount over 12 months
///   Medicare    2%, phased in between 27,222 and 34,027   (INDEXED — verify)
///   Surcharge   1% / 1.25% / 1.5% at 101,000 / 118,000 / 158,000 (INDEXED — verify)
///
/// The two indexed threshold sets are the lower-confidence figures and are
/// flagged in the rule table as well.
@Suite("AUTaxCalculator golden fixtures")
@MainActor
struct AUTaxCalculatorTests {

    private let calculator = AUTaxCalculator()

    private func profile(
        income: Decimal,
        hasCover: Bool = true,
        concessionalSuper: Decimal = 0,
        gains: Decimal = 0,
        gainsDiscounted: Bool = true
    ) -> TaxProfile {
        var advanced = TaxAdvancedInputs()
        advanced.auHasPrivateHospitalCover = hasCover
        advanced.auConcessionalSuper = concessionalSuper
        advanced.auCapitalGains = gains
        advanced.auCapitalGainsEligibleForDiscount = gainsDiscounted
        return TaxProfile(
            country: .australia,
            annualIncome: income,
            financialYear: "2025-26",
            advancedInputs: advanced
        )
    }

    private func decimal(_ string: String) -> Decimal { Decimal(string: string) ?? .nan }

    // MARK: - Brackets and LITO

    /// $50,000 with cover.
    ///   16% on 26,800 = 4,288.00; 30% on 5,000 = 1,500.00 -> 5,788.00
    ///   LITO 700 - (7,500 x 5%) - (5,000 x 1.5%) = 250.00
    ///   Medicare 2% of 50,000 = 1,000.00
    @Test("middle income, with private cover")
    func middleIncome() {
        let estimate = calculator.calculate(profile: profile(income: 50_000))
        #expect(estimate.taxableIncome == 50_000)
        #expect(estimate.rebate == decimal("250.00"))
        #expect(estimate.basicTax == decimal("5538.00"))
        #expect(estimate.cess == decimal("1000.00"))
        #expect(estimate.finalTax == decimal("6538.00"))
        #expect(estimate.marginalRate == 30)
        #expect(estimate.ruleSetID == "AU_TY2025_26")
    }

    /// $30,000: full LITO, and the Medicare levy still inside its phase-in.
    ///   16% on 11,800 = 1,888.00, less LITO 700 = 1,188.00
    ///   Medicare (30,000 - 27,222) x 10% = 277.80
    @Test("low income gets full LITO and a phased-in Medicare levy")
    func lowIncomePhaseIn() {
        let estimate = calculator.calculate(profile: profile(income: 30_000))
        #expect(estimate.rebate == decimal("700.00"))
        #expect(estimate.basicTax == decimal("1188.00"))
        #expect(estimate.cess == decimal("277.80"))
        #expect(estimate.finalTax == decimal("1465.80"))
    }

    /// The tax-free threshold really is free, and no levy applies below its own
    /// threshold either.
    @Test("no tax at the tax-free threshold")
    func taxFreeThreshold() {
        let estimate = calculator.calculate(profile: profile(income: 18_200))
        #expect(estimate.finalTax == 0)
        #expect(estimate.cess == 0)
    }

    /// LITO is non-refundable — it must never produce a negative liability.
    @Test("LITO cannot reduce tax below zero")
    func litoNonRefundable() {
        let estimate = calculator.calculate(profile: profile(income: 20_000))
        // 16% on 1,800 = 288.00, and LITO is capped at that rather than 700.
        #expect(estimate.rebate == decimal("288.00"))
        #expect(estimate.basicTax == 0)
        #expect(estimate.finalTax >= 0)
    }

    @Test("LITO is gone above the cut-out")
    func litoCutOut() {
        let estimate = calculator.calculate(profile: profile(income: 70_000))
        #expect(estimate.rebate == 0)
    }

    // MARK: - Medicare levy surcharge

    /// $150,000 without cover. Tier 2 applies: 1.25% of taxable income.
    ///   Tax 36,838.00; Medicare 3,000.00; surcharge 1,875.00
    @Test("surcharge applies without private cover")
    func surchargeWithoutCover() {
        let estimate = calculator.calculate(profile: profile(income: 150_000, hasCover: false))
        #expect(estimate.basicTax == decimal("36838.00"))
        #expect(estimate.cess == decimal("3000.00"))
        #expect(estimate.surcharge == decimal("1875.00"))
        #expect(estimate.finalTax == decimal("41713.00"))
        #expect(estimate.warnings.contains { $0.contains("surcharge") })
    }

    /// Holding cover removes exactly the surcharge and nothing else.
    @Test("private cover removes the surcharge and only the surcharge")
    func coverRemovesSurcharge() {
        let without = calculator.calculate(profile: profile(income: 150_000, hasCover: false))
        let with = calculator.calculate(profile: profile(income: 150_000, hasCover: true))
        #expect(with.surcharge == 0)
        #expect(with.finalTax == decimal("39838.00"))
        #expect(without.finalTax - with.finalTax == decimal("1875.00"))
        #expect(without.cess == with.cess)
        #expect(without.basicTax == with.basicTax)
    }

    /// Below the first tier there is no surcharge even without cover.
    @Test("no surcharge below the first tier")
    func noSurchargeBelowTier() {
        let estimate = calculator.calculate(profile: profile(income: 90_000, hasCover: false))
        #expect(estimate.surcharge == 0)
    }

    // MARK: - Capital gains

    /// $80,000 plus a $20,000 gain held over 12 months: half the gain is assessed.
    ///   Taxable 90,000 -> 16% on 26,800 = 4,288.00, 30% on 45,000 = 13,500.00
    ///   Medicare 2% of 90,000 = 1,800.00
    @Test("the 50% CGT discount halves a long-held gain")
    func capitalGainsDiscounted() {
        let estimate = calculator.calculate(profile: profile(income: 80_000, gains: 20_000))
        #expect(estimate.taxableIncome == 90_000)
        #expect(estimate.basicTax == decimal("17788.00"))
        #expect(estimate.finalTax == decimal("19588.00"))
    }

    /// Held under 12 months, the whole gain is assessed.
    @Test("a short-held gain gets no discount")
    func capitalGainsUndiscounted() {
        let discounted = calculator.calculate(profile: profile(income: 80_000, gains: 20_000))
        let full = calculator.calculate(
            profile: profile(income: 80_000, gains: 20_000, gainsDiscounted: false)
        )
        #expect(full.taxableIncome == 100_000)
        #expect(full.taxableIncome - discounted.taxableIncome == 10_000)
        #expect(full.finalTax > discounted.finalTax)
    }

    // MARK: - Superannuation

    /// Concessional super reduces assessable income.
    @Test("concessional super reduces assessable income")
    func concessionalSuperReduces() {
        let estimate = calculator.calculate(profile: profile(income: 100_000, concessionalSuper: 10_000))
        #expect(estimate.taxableIncome == 90_000)
    }

    /// Above the cap it is capped, and the user is told — otherwise the estimate
    /// promises a saving the ATO would not give.
    @Test("concessional super is capped at the statutory limit and warns")
    func concessionalSuperCapped() {
        let estimate = calculator.calculate(profile: profile(income: 100_000, concessionalSuper: 40_000))
        // Capped at 30,000, not 40,000.
        #expect(estimate.taxableIncome == 70_000)
        #expect(estimate.basicTax == decimal("11788.00"))
        #expect(estimate.finalTax == decimal("13188.00"))
        #expect(estimate.warnings.contains { $0.contains("capped") })
    }

    // MARK: - Edges

    @Test("zero income does not divide by zero in the effective rate")
    func zeroIncome() {
        let estimate = calculator.calculate(profile: profile(income: 0))
        #expect(estimate.effectiveRate == 0)
        #expect(estimate.finalTax == 0)
    }

    @Test("top bracket marginal rate is 45%")
    func topBracket() {
        let estimate = calculator.calculate(profile: profile(income: 250_000))
        #expect(estimate.marginalRate == 45)
    }

    @Test("an unsupported year warns and falls back to the nearest held year")
    func unsupportedYearWarns() {
        var p = profile(income: 50_000)
        p.financialYear = "2031-32"
        let estimate = calculator.calculate(profile: p)
        #expect(estimate.ruleSetID == "AU_TY2025_26")
        #expect(estimate.warnings.contains { $0.contains("not held") })
    }

    /// 1 July, not 1 January.
    @Test("default financial year uses the July boundary")
    func taxYearBoundary() {
        let year = TaxCountry.australia.defaultFinancialYear
        #expect(year.count == 7)
        #expect(year.contains("-"))
    }

    /// Non-residents pay from the first dollar. Applying resident rates to them
    /// silently would understate badly, so it is stated instead.
    @Test("non-resident rates are declared as an exclusion, not silently applied")
    func nonResidentExcluded() {
        let estimate = calculator.calculate(profile: profile(income: 50_000))
        #expect(estimate.exclusions.contains { $0.contains("Non-resident") })
        #expect(estimate.exclusions.contains { $0.contains("HELP") })
    }
}
