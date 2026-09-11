import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Per-tax-year golden snapshot of the US and India rule tables.
///
/// Two layers:
///  1. **Table layer** — exact dump of every US standard deduction and bracket
///     bound/rate, per tax year per filing status. A single transposed digit in
///     the rule table fails here with a readable diff.
///  2. **Behaviour layer** — computed outputs at slab edges for both countries,
///     covering what the per-status table does not: preferential LTCG stacking,
///     payroll wage bases, NIIT, the age-65 add-on, contribution headroom, and
///     India's rebate / surcharge / marginal-relief / cess chain.
///
/// The fixtures below were generated from the calculators **before** the rule
/// data was moved into `USTaxRuleTable` / `IndiaTaxRuleTable`, so they pin the
/// pre-refactor behaviour and are never to be regenerated to make a change pass.
/// Adding a tax year means adding rows, never editing existing ones.
@Suite("Tax Rule Table Golden Snapshot")
@MainActor
struct TaxRuleTableGoldenTests {

    // MARK: - Grid definitions

    /// Years that exercise both clamp ends as well as every modeled year.
    static let usTaxYears = [2023, 2024, 2025, 2026, 2027]

    static let usStatuses: [USFilingStatus] = [
        .single,
        .marriedFilingJointly,
        .marriedFilingSeparately,
        .headOfHousehold,
        .qualifyingSurvivingSpouse,
    ]

    /// Probes placed at and around modeled US bracket edges.
    static let usIncomes: [Decimal] = [
        0, 12_400, 24_800, 50_400, 67_450, 100_800, 105_700,
        197_300, 211_400, 256_225, 403_550, 626_350, 768_700, 1_000_000,
    ]

    static let indiaFinancialYears = ["2023-24", "2024-25", "2025-26", "2026-27"]

    /// Probes placed at modeled India slab edges plus every surcharge threshold.
    static let indiaIncomes: [Decimal] = [
        0, 2_50_000, 3_00_000, 5_00_000, 7_00_000, 8_00_000, 10_00_000,
        12_00_000, 15_00_000, 16_00_000, 20_00_000, 24_00_000,
        50_00_000, 55_00_000, 1_00_00_000, 1_10_00_000,
        2_00_00_000, 2_50_00_000, 5_00_00_000, 6_00_00_000,
    ]

    // MARK: - Row formatting

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    /// Exact dump of one US (year, status) rule-table entry.
    static func usTableRow(taxYear: Int, status: USFilingStatus) -> String {
        let deduction = decimalString(USTaxCalculator.standardDeduction(for: status, taxYear: taxYear))
        let brackets = USTaxCalculator.brackets(for: status, taxYear: taxYear)
            .map { slab in
                let upper = slab.upper.map(decimalString) ?? "inf"
                return "\(decimalString(slab.lower))-\(upper)@\(decimalString(slab.ratePercent))"
            }
            .joined(separator: ";")
        return "\(taxYear)|\(status.rawValue)|\(deduction)|\(brackets)"
    }

    /// Computed outputs for one profile, reduced to a single comparable line.
    static func behaviourRow(label: String, estimate: TaxEstimate) -> String {
        let supplementary = estimate.supplementaryLines.reduce(Decimal(0)) { $0 + $1.amount }
        let fields = [
            decimalString(estimate.taxableIncome),
            decimalString(estimate.standardDeduction),
            decimalString(estimate.customDeductionsTotal),
            decimalString(estimate.basicTax),
            decimalString(estimate.rebate),
            decimalString(estimate.surcharge),
            decimalString(estimate.cess),
            decimalString(estimate.finalTax),
            decimalString(estimate.marginalRate),
            decimalString(supplementary),
            estimate.ruleSetID,
        ]
        return "\(label)|\(fields.joined(separator: "|"))"
    }

    private static func date(year: Int) -> Date {
        // June 15 keeps every age computation far from a year boundary, so the
        // snapshot does not shift with the host time zone.
        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: year,
            month: 6,
            day: 15
        )
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: - Grid generation

    static func usTableRows() -> [String] {
        usTaxYears.flatMap { year in
            usStatuses.map { usTableRow(taxYear: year, status: $0) }
        }
    }

    static func usBehaviourRows() -> [String] {
        let calc = USTaxCalculator()
        var rows: [String] = []

        // Plain wage income across every year, status and bracket-edge probe.
        for year in usTaxYears {
            for status in usStatuses {
                for income in usIncomes {
                    let profile = TaxProfile(
                        country: .unitedStates,
                        annualIncome: income,
                        filingStatus: status,
                        financialYear: "\(year)"
                    )
                    rows.append(
                        behaviourRow(
                            label: "US|wage|\(year)|\(status.rawValue)|\(decimalString(income))",
                            estimate: calc.calculate(profile: profile)
                        )
                    )
                }
            }
        }

        // Preferential rates, NIIT, age-65 add-on and contribution headroom.
        for year in [2024, 2025, 2026] {
            for status in usStatuses {
                let advanced = TaxAdvancedInputs(
                    usQualifiedDividends: 20_000,
                    usLongTermCapitalGains: 120_000,
                    usShortTermCapitalGains: 15_000,
                    usOtherInvestmentIncome: 9_000,
                    us401kYTDContributed: 10_000,
                    usIRAYTDContributed: 3_000,
                    usHSAYTDContributed: 2_000,
                    usHSAFamilyCoverage: true
                )
                let profile = TaxProfile(
                    country: .unitedStates,
                    annualIncome: 240_000,
                    filingStatus: status,
                    financialYear: "\(year)",
                    dateOfBirth: date(year: year - 70),
                    advancedInputs: advanced
                )
                rows.append(
                    behaviourRow(
                        label: "US|advanced|\(year)|\(status.rawValue)",
                        estimate: calc.calculate(profile: profile)
                    )
                )
            }
        }

        // Deduction-mode behaviour against a large itemized total.
        for mode in [USDeductionMode.bestAvailable, .standardOnly, .itemizedOnly] {
            let profile = TaxProfile(
                country: .unitedStates,
                annualIncome: 180_000,
                filingStatus: .single,
                customDeductions: [TaxDeduction(name: "Itemized", amount: 40_000)],
                financialYear: "2026"
            )
            rows.append(
                behaviourRow(
                    label: "US|mode|2026|\(mode)",
                    estimate: calc.calculate(profile: profile, deductionMode: mode)
                )
            )
        }

        return rows
    }

    static func indiaBehaviourRows() -> [String] {
        let calc = IndiaTaxCalculator()
        var rows: [String] = []

        for year in indiaFinancialYears {
            for regime in IndiaRegime.allCases {
                for income in indiaIncomes {
                    let profile = TaxProfile(
                        country: .india,
                        annualIncome: income,
                        indiaRegime: regime,
                        financialYear: year
                    )
                    rows.append(
                        behaviourRow(
                            label: "IN|salaried|\(year)|\(regime.rawValue)|\(decimalString(income))",
                            estimate: calc.calculate(profile: profile)
                        )
                    )
                }
            }
        }

        // Self-employed drops the standard deduction entirely.
        for year in indiaFinancialYears {
            for regime in IndiaRegime.allCases {
                let profile = TaxProfile(
                    country: .india,
                    annualIncome: 15_00_000,
                    indiaRegime: regime,
                    financialYear: year,
                    incomeSourceType: .selfEmployed
                )
                rows.append(
                    behaviourRow(
                        label: "IN|selfEmployed|\(year)|\(regime.rawValue)",
                        estimate: calc.calculate(profile: profile)
                    )
                )
            }
        }

        // Old-regime age tiers change the basic exemption slab.
        for birthYear in [1990, 1960, 1940] {
            for year in ["2024-25", "2025-26"] {
                let profile = TaxProfile(
                    country: .india,
                    annualIncome: 10_00_000,
                    indiaRegime: .oldRegime,
                    financialYear: year,
                    dateOfBirth: date(year: birthYear)
                )
                rows.append(
                    behaviourRow(
                        label: "IN|age|\(year)|\(birthYear)",
                        estimate: calc.calculate(profile: profile)
                    )
                )
            }
        }

        // Equity LTCG/STCG special rates plus the 15% surcharge cap.
        for income in [Decimal(20_00_000), 1_10_00_000, 6_00_00_000] {
            for year in ["2024-25", "2025-26"] {
                let advanced = TaxAdvancedInputs(
                    indiaEquityLTCG: 4_00_000,
                    indiaEquitySTCG: 2_00_000
                )
                let profile = TaxProfile(
                    country: .india,
                    annualIncome: income,
                    indiaRegime: .newRegime,
                    financialYear: year,
                    advancedInputs: advanced
                )
                rows.append(
                    behaviourRow(
                        label: "IN|equity|\(year)|\(decimalString(income))",
                        estimate: calc.calculate(profile: profile)
                    )
                )
            }
        }

        // Old-regime section deductions and HRA.
        for year in ["2024-25", "2025-26"] {
            let advanced = TaxAdvancedInputs(
                indiaBasicSalary: 6_00_000,
                indiaHRAPaid: 2_40_000,
                indiaRentPaid: 3_00_000,
                indiaMetroCity: true
            )
            let profile = TaxProfile(
                country: .india,
                annualIncome: 18_00_000,
                indiaRegime: .oldRegime,
                customDeductions: [
                    TaxDeduction(name: "PPF", amount: 2_00_000, section: "80C"),
                    TaxDeduction(name: "NPS", amount: 60_000, section: "80CCD(1B)"),
                    TaxDeduction(name: "Health", amount: 40_000, section: "80D"),
                ],
                financialYear: year,
                advancedInputs: advanced
            )
            rows.append(
                behaviourRow(
                    label: "IN|deductions|\(year)",
                    estimate: calc.calculate(profile: profile)
                )
            )
        }

        return rows
    }

    // MARK: - Tests

    @Test("US rule table matches the per-year golden dump")
    func usRuleTableMatchesGolden() {
        assertRows(Self.usTableRows(), matches: TaxGoldenFixtures.usTable, name: "usTable")
    }

    @Test("US computed output matches the per-year golden dump")
    func usBehaviourMatchesGolden() {
        assertRows(Self.usBehaviourRows(), matches: TaxGoldenFixtures.usBehaviour, name: "usBehaviour")
    }

    @Test("India computed output matches the per-year golden dump")
    func indiaBehaviourMatchesGolden() {
        assertRows(Self.indiaBehaviourRows(), matches: TaxGoldenFixtures.indiaBehaviour, name: "indiaBehaviour")
    }

    /// Compares row-by-row so a failure names the exact profile that drifted
    /// rather than dumping a several-hundred-line array diff.
    private func assertRows(_ actual: [String], matches expected: [String], name: String) {
        #expect(actual.count == expected.count, "\(name): row count changed")
        for (index, row) in actual.enumerated() where index < expected.count {
            #expect(row == expected[index], "\(name) row \(index) drifted")
        }
    }
}
