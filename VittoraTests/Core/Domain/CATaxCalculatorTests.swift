import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Canadian tax golden fixtures for tax year 2025 (CA_TY2025).
///
/// # Confidence
///
/// Federal figures and the contribution mechanics are high confidence. **Every
/// provincial expectation below inherits the VERIFY status of its table in
/// `CATaxRuleTable`** — the brackets and basic personal amounts were derived,
/// not sourced, and the owner checks them before release. A wrong provincial
/// bracket is a wrong number for everyone in that province.
///
/// Rates used:
///   Federal   14.5 / 20.5 / 26 / 29 / 33%, BPA 16,129 tapering to 14,538
///   CPP       5.95% on 3,500–71,300, then CPP2 4% on 71,300–81,200
///   EI        1.64% to 65,700 (Quebec 1.31%)
///   Quebec    16.5% federal abatement
///   Gains     50% inclusion
@Suite("CATaxCalculator golden fixtures")
@MainActor
struct CATaxCalculatorTests {

    private let calculator = CATaxCalculator()

    private func profile(
        income: Decimal,
        province: CAProvince = .ontario,
        rrsp: Decimal = 0,
        gains: Decimal = 0
    ) -> TaxProfile {
        var advanced = TaxAdvancedInputs()
        advanced.caProvince = province
        advanced.caRRSPContributions = rrsp
        advanced.caCapitalGains = gains
        return TaxProfile(
            country: .canada,
            annualIncome: income,
            financialYear: "2025",
            advancedInputs: advanced
        )
    }

    private func decimal(_ string: String) -> Decimal { Decimal(string: string) ?? .nan }

    private func line(_ estimate: TaxEstimate, _ needle: String) -> Decimal? {
        estimate.supplementaryLines.first { $0.title.contains(needle) }?.amount
    }

    // MARK: - Two levels

    /// Ontario $60,000.
    ///   Federal   gross - (16,129 x 14.5%) = 6,518.80
    ///   Ontario   gross - (12,747 x 5.05%) = 2,677.95, no surtax at this level
    ///   CPP 3,361.75 (base + CPP2 does not apply), EI 984.00
    @Test("federal and provincial tax are both charged, not one or the other")
    func ontarioMiddleIncome() {
        let estimate = calculator.calculate(profile: profile(income: 60_000))
        #expect(estimate.basicTax == decimal("6518.80"))
        #expect(estimate.surcharge == decimal("2677.95"))
        #expect(estimate.finalTax == decimal("13542.50"))
        #expect(estimate.ruleSetID == "CA_TY2025_ON")
        // Federal-only would have been roughly a third light — the whole reason
        // provincial tables exist here.
        #expect(estimate.surcharge > 0)
    }

    /// Ontario $120,000 — high enough for both surtax rungs.
    ///   Ontario before surtax 8,453.87, surtax 961.64, total 9,415.51
    ///   CPP 4,430.10 includes the CPP2 tier; EI capped at 1,077.48
    @Test("Ontario surtax is charged on provincial tax, not on income")
    func ontarioSurtax() {
        let estimate = calculator.calculate(profile: profile(income: 120_000))
        #expect(estimate.basicTax == decimal("19107.55"))
        #expect(estimate.surcharge == decimal("9415.51"))
        #expect(line(estimate, "surtax") == decimal("961.64"))
        #expect(estimate.finalTax == decimal("34030.64"))
    }

    /// Quebec $60,000 — the abatement and the lower EI rate both apply.
    ///   Federal before abatement 6,518.80, abatement 1,075.60, federal 5,443.20
    ///   Quebec tax 6,137.31; EI at the Quebec rate is 786.00, not 984.00
    @Test("Quebec gets the federal abatement and the lower EI rate")
    func quebecAbatement() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, province: .quebec))
        #expect(estimate.basicTax == decimal("5443.20"))
        #expect(line(estimate, "abatement") == decimal("-1075.60"))
        #expect(estimate.surcharge == decimal("6137.31"))
        #expect(estimate.finalTax == decimal("15728.26"))
        #expect(line(estimate, "EI") == decimal("786.00"))
        // Labelled QPP in Quebec, CPP elsewhere.
        #expect(line(estimate, "QPP") != nil)
    }

    /// Missing the abatement would overstate a Quebec bill by over a thousand
    /// dollars at this income.
    @Test("the abatement materially reduces Quebec federal tax")
    func abatementIsMaterial() {
        let quebec = calculator.calculate(profile: profile(income: 60_000, province: .quebec))
        let ontario = calculator.calculate(profile: profile(income: 60_000, province: .ontario))
        #expect(quebec.basicTax < ontario.basicTax)
        #expect(ontario.basicTax - quebec.basicTax == decimal("1075.60"))
    }

    /// Alberta $60,000 — a different provincial table on identical federal tax.
    @Test("province changes the bill while federal tax stays the same")
    func provinceChangesBill() {
        let alberta = calculator.calculate(profile: profile(income: 60_000, province: .alberta))
        let ontario = calculator.calculate(profile: profile(income: 60_000, province: .ontario))
        #expect(alberta.basicTax == ontario.basicTax)
        #expect(alberta.surcharge == decimal("3014.16"))
        #expect(alberta.finalTax == decimal("13878.71"))
        #expect(alberta.finalTax != ontario.finalTax)
    }

    // MARK: - Credits, not deductions

    /// The basic personal amount is a credit at the lowest rate. Treating it as a
    /// deduction would understate tax at every income above the lowest bracket,
    /// which is the single easiest way to get Canada wrong.
    @Test("basic personal amounts are credits at the lowest rate, not deductions")
    func bpaIsCredit() {
        let estimate = calculator.calculate(profile: profile(income: 120_000))
        // Taxable income is NOT reduced by the BPA.
        #expect(estimate.taxableIncome == 120_000)
        // Federal credit is 16,129 x 14.5% = 2,338.71, far less than deducting it
        // would be worth at this income's 26% marginal rate.
        #expect(estimate.rebate > 0)
    }

    /// The federal BPA tapers to a floor, not to zero — unlike the UK allowance.
    @Test("federal basic personal amount tapers to a floor, never to zero")
    func bpaTapersToFloor() {
        let high = calculator.calculate(profile: profile(income: 300_000))
        #expect(high.standardDeduction == 14_538)

        let low = calculator.calculate(profile: profile(income: 60_000))
        #expect(low.standardDeduction == 16_129)
    }

    // MARK: - Contributions

    /// CPP2 applies only above the year's maximum pensionable earnings.
    @Test("CPP2 applies above the maximum pensionable earnings")
    func cppSecondTier() {
        let below = calculator.calculate(profile: profile(income: 71_300))
        let above = calculator.calculate(profile: profile(income: 81_200))
        // Base maximum, then the full CPP2 band on top.
        #expect(line(below, "CPP") == decimal("4034.10"))
        #expect(line(above, "CPP") == decimal("4430.10"))
    }

    @Test("EI is capped at the maximum insurable earnings")
    func eiCapped() {
        let atCap = calculator.calculate(profile: profile(income: 65_700))
        let wellAbove = calculator.calculate(profile: profile(income: 200_000))
        #expect(line(atCap, "EI") == line(wellAbove, "EI"))
        #expect(line(atCap, "EI") == decimal("1077.48"))
    }

    // MARK: - Gains and RRSP

    @Test("half of a capital gain is included in income")
    func capitalGainsInclusion() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, gains: 20_000))
        #expect(estimate.taxableIncome == 70_000)
    }

    @Test("RRSP contributions reduce taxable income")
    func rrspDeducts() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, rrsp: 10_000))
        #expect(estimate.taxableIncome == 50_000)
    }

    // MARK: - Coverage and honesty

    /// All thirteen must produce an estimate. A missing province would silently
    /// fall back to federal brackets, which would be wrong rather than absent.
    @Test("every province and territory produces a distinct provincial figure")
    func allThirteenCovered() {
        for province in CAProvince.allCases {
            let estimate = calculator.calculate(profile: profile(income: 80_000, province: province))
            #expect(estimate.surcharge > 0, "\(province.rawValue) produced no provincial tax")
            #expect(estimate.ruleSetID == "CA_TY2025_\(province.rawValue)")
        }
    }

    /// Provincial figures are unverified, and the estimate must say so rather
    /// than presenting them as authoritative.
    @Test("the estimate warns that provincial figures are unverified")
    func provincialWarningPresent() {
        let estimate = calculator.calculate(profile: profile(income: 60_000))
        #expect(estimate.warnings.contains { $0.contains("verified") })
    }

    @Test("zero income does not divide by zero in the effective rate")
    func zeroIncome() {
        let estimate = calculator.calculate(profile: profile(income: 0))
        #expect(estimate.effectiveRate == 0)
        #expect(estimate.finalTax == 0)
    }

    @Test("an unsupported year warns and falls back to the nearest held year")
    func unsupportedYearWarns() {
        var p = profile(income: 60_000)
        p.financialYear = "2031"
        let estimate = calculator.calculate(profile: p)
        #expect(estimate.ruleSetID == "CA_TY2025_ON")
        #expect(estimate.warnings.contains { $0.contains("not held") })
    }

    /// The marginal rate a Canadian plans against is combined, not either level.
    @Test("marginal rate combines federal and provincial")
    func combinedMarginalRate() {
        let estimate = calculator.calculate(profile: profile(income: 60_000))
        // 20.5% federal + 9.15% Ontario
        #expect(estimate.marginalRate == decimal("29.65"))
    }
}
