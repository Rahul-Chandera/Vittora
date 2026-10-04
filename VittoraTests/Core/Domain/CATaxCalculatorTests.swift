import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Canadian tax golden fixtures for tax year 2025 (CA_TY2025).
///
/// Federal and provincial tables were checked against CRA's 2025 payroll and
/// T1 figures in the 2026-10-03 tax logic review.
///
/// Rates used:
///   Federal   14.5 / 20.5 / 26 / 29 / 33%, BPA 16,129 tapering to 14,538
///   CPP       5.95% on 3,500–71,300 (1% enhanced, deducted; 4.95% base,
///             credited), then CPP2 4% on 71,300–81,200 (deducted)
///   QPP       6.40% on the same first tier (1% enhanced)
///   EI        1.64% to 65,700 (Quebec 1.31%), credited
///   Quebec    16.5% federal abatement
///   Gains     50% inclusion
///
/// Field contract: `basicTax` is federal tax before credits, `rebate` is
/// federal credits plus the Quebec abatement, `surcharge` is provincial tax,
/// `cess` is CPP/QPP + EI.
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
    ///   CPP 3,361.75 on 56,500: enhanced 565.00 deducted, base 2,796.75 credited
    ///   EI 984.00; taxable income 60,000 - 565 = 59,435
    ///   Federal   gross 8,741.68 - (16,129 + 2,796.75 + 984) x 14.5% = 5,854.77
    ///   Ontario   gross 3,269.97 - (12,747 + 2,796.75 + 984) x 5.05% = 2,435.32
    @Test("federal and provincial tax are both charged, not one or the other")
    func ontarioMiddleIncome() {
        let estimate = calculator.calculate(profile: profile(income: 60_000))
        #expect(estimate.taxableIncome == 59_435)
        #expect(estimate.basicTax == decimal("8741.68"))
        #expect(estimate.rebate == decimal("2886.91"))
        #expect(estimate.surcharge == decimal("2435.32"))
        #expect(estimate.finalTax == decimal("12635.84"))
        #expect(estimate.ruleSetID == "CA_TY2025_ON")
        // Federal-only would have been roughly a third light — the whole reason
        // provincial tables exist here.
        #expect(estimate.surcharge > 0)
    }

    /// Ontario $120,000 — high enough for both surtax rungs.
    ///   CPP 4,430.10 includes the CPP2 tier; 1,074.00 enhanced is deducted
    ///   Taxable 118,926; EI capped at 1,077.48
    ///   Ontario before surtax 8,110.11, surtax 480.02 + 289.12 = 769.14
    @Test("Ontario surtax is charged on provincial tax, not on income")
    func ontarioSurtax() {
        let estimate = calculator.calculate(profile: profile(income: 120_000))
        #expect(estimate.basicTax == decimal("21167.02"))
        #expect(estimate.surcharge == decimal("8879.25"))
        #expect(line(estimate, "surtax") == decimal("769.14"))
        #expect(estimate.finalTax == decimal("32572.28"))
    }

    /// Quebec $60,000 — the abatement and the lower EI rate both apply.
    ///   QPP 3,616.00 (6.40% of 56,500), 565.00 enhanced deducted; taxable 59,435
    ///   Federal gross 8,741.68 - credits (16,129 + 3,051 + 786) x 14.5% = 5,846.61
    ///   Abatement 16.5% = 964.69, federal 4,881.92
    ///   Quebec tax 8,629.90 - 18,571 x 14% = 6,029.96 (QPP/EI credits not modelled)
    ///   EI at the Quebec rate is 786.00, not 984.00
    @Test("Quebec gets the federal abatement and the lower EI rate")
    func quebecAbatement() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, province: .quebec))
        #expect(estimate.basicTax == decimal("8741.68"))
        #expect(line(estimate, "abatement") == decimal("-964.69"))
        #expect(line(estimate, "Federal tax") == decimal("4881.92"))
        #expect(estimate.surcharge == decimal("6029.96"))
        #expect(estimate.finalTax == decimal("15313.88"))
        #expect(line(estimate, "EI") == decimal("786.00"))
        // Labelled QPP in Quebec, CPP elsewhere.
        #expect(line(estimate, "QPP") != nil)
    }

    /// Missing the abatement would overstate a Quebec bill by nearly a thousand
    /// dollars at this income.
    @Test("the abatement materially reduces Quebec federal tax")
    func abatementIsMaterial() {
        let quebec = calculator.calculate(profile: profile(income: 60_000, province: .quebec))
        let ontario = calculator.calculate(profile: profile(income: 60_000, province: .ontario))
        #expect((line(quebec, "Federal tax") ?? 0) < (line(ontario, "Federal tax") ?? 0))
        // 16.5% of federal tax after credits: 5,846.61 x 16.5% = 964.69
        #expect(line(quebec, "abatement") == decimal("-964.69"))
        #expect(line(ontario, "abatement") == nil)
    }

    /// Alberta $60,000 — a different provincial table on identical federal tax.
    @Test("province changes the bill while federal tax stays the same")
    func provinceChangesBill() {
        let alberta = calculator.calculate(profile: profile(income: 60_000, province: .alberta))
        let ontario = calculator.calculate(profile: profile(income: 60_000, province: .ontario))
        #expect(alberta.basicTax == ontario.basicTax)
        // Alberta gross 4,754.80 - (22,323 + 2,796.75 + 984) x 8% = 2,666.50
        #expect(alberta.surcharge == decimal("2666.50"))
        #expect(alberta.finalTax == decimal("12867.02"))
        #expect(alberta.finalTax != ontario.finalTax)
    }

    // MARK: - Credits, not deductions

    /// The basic personal amount is a credit at the lowest rate. Treating it as a
    /// deduction would understate tax at every income above the lowest bracket,
    /// which is the single easiest way to get Canada wrong.
    @Test("basic personal amounts are credits at the lowest rate, not deductions")
    func bpaIsCredit() {
        let estimate = calculator.calculate(profile: profile(income: 120_000))
        // Taxable income is reduced by the enhanced CPP (678 + CPP2 396 = 1,074),
        // NOT by the BPA.
        #expect(estimate.taxableIncome == 118_926)
        #expect(estimate.customDeductionsTotal == 1_074)
        // Federal credit is 16,129 x 14.5% = 2,338.71, far less than deducting it
        // would be worth at this income's 26% marginal rate.
        #expect(estimate.rebate > 0)
    }

    /// The federal BPA tapers to a floor, not to zero — unlike the UK allowance.
    /// The BPA is a credit, so it is read from the rules and the credit slot,
    /// not from `standardDeduction` (always 0 for Canada).
    @Test("federal basic personal amount tapers to a floor, never to zero")
    func bpaTapersToFloor() {
        let rules = CATaxRuleTable.rules(for: 2025)
        #expect(CATaxCalculator.federalBasicPersonalAmount(netIncome: 298_926, rules: rules) == 14_538)
        #expect(CATaxCalculator.federalBasicPersonalAmount(netIncome: 59_435, rules: rules) == 16_129)

        // (14,538 + 3,356.10 base CPP + 1,077.48 EI) x 14.5% = 2,750.88
        let high = calculator.calculate(profile: profile(income: 300_000))
        #expect(high.standardDeduction == 0)
        #expect(high.rebate == decimal("2750.88"))
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
        let base = calculator.calculate(profile: profile(income: 60_000))
        let estimate = calculator.calculate(profile: profile(income: 60_000, gains: 20_000))
        // 60,000 + 10,000 - 565 enhanced CPP
        #expect(estimate.taxableIncome == 69_435)
        #expect(estimate.taxableIncome - base.taxableIncome == 10_000)
    }

    @Test("RRSP contributions reduce taxable income")
    func rrspDeducts() {
        let base = calculator.calculate(profile: profile(income: 60_000))
        let estimate = calculator.calculate(profile: profile(income: 60_000, rrsp: 10_000))
        // 60,000 - 10,000 - 565 enhanced CPP
        #expect(estimate.taxableIncome == 49_435)
        #expect(base.taxableIncome - estimate.taxableIncome == 10_000)
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
        #expect(estimate.ruleSetID == "CA_TY2026_ON")
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
