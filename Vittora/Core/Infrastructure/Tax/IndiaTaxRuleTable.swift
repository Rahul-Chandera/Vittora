import Foundation
import VittoraCore

/// In-binary India income-tax rule table keyed by financial year (FY start year).
/// Adding a future year is a pure data edit here — no calculator logic changes.
enum IndiaTaxRuleTable {
    struct RebateRules: Sendable {
        let threshold: Decimal
        let cap: Decimal
    }

    /// One rung of the surcharge ladder: the income it starts above, and the
    /// rate each regime charges there. Only the top rung currently differs
    /// between regimes, but both are stated on every rung so a future year that
    /// splits a lower rung is a data edit.
    struct SurchargeBand: Sendable {
        let threshold: Decimal
        let newRegimeRate: Decimal
        let oldRegimeRate: Decimal
    }

    struct SurchargeRules: Sendable {
        /// Ascending by threshold. The applicable band is the last one the
        /// income exceeds — indexing into this is deliberately not how it is
        /// read, so that adding or splitting a band stays a pure data edit.
        let bands: [SurchargeBand]
        /// Surcharge on equity LTCG/STCG is capped here even when the nominal
        /// rate is higher (Sections 111A/112A-style modeling).
        let specialRateCap: Decimal
        /// Income above which the equity surcharge-cap warning is surfaced.
        let specialRateCapWarningThreshold: Decimal

        /// Thresholds used by the marginal-relief walk.
        nonisolated var thresholds: [Decimal] { bands.map(\.threshold) }

        nonisolated func nominalRate(grossIncome: Decimal, regime: IndiaRegime) -> Decimal {
            guard let band = bands.last(where: { grossIncome > $0.threshold }) else { return 0 }
            return regime == .newRegime ? band.newRegimeRate : band.oldRegimeRate
        }
    }

    /// Exhaustive per-age-category old-regime slabs; calculator selects which list.
    struct OldRegimeByAge: Sendable {
        let regular: [TaxSlab]
        let senior: [TaxSlab]
        let superSenior: [TaxSlab]
    }

    struct YearRules: Sendable {
        let ruleSetID: String
        let newRegimeSlabs: [TaxSlab]
        let oldRegimeByAge: OldRegimeByAge
        let newRegimeSalariedStandardDeduction: Decimal
        let oldRegimeSalariedStandardDeduction: Decimal
        let newRegimeRebate: RebateRules
        let oldRegimeRebate: RebateRules
        let surcharge: SurchargeRules
        let cessRate: Decimal
        let equityLTCGRate: Decimal
        let equityLTCGExemption: Decimal
        let equitySTCGRate: Decimal
    }

    private struct Entry: Sendable {
        let year: Int
        let rules: YearRules
    }

    /// Ascending by year. Lookup floors to the latest row not after the request.
    nonisolated private static let entries: [Entry] = [
        Entry(year: 2024, rules: year2024),
        Entry(year: 2025, rules: year2025),
    ]

    nonisolated static var financialYears: [Int] {
        entries.map(\.year)
    }

    nonisolated static var latestFinancialYear: Int {
        entries.map(\.year).max() ?? entries[0].year
    }

    /// Resolves to the most recent year in the table that is **not later than**
    /// `financialYear`, clamping up to the earliest year when `financialYear`
    /// precedes the whole table. With the contiguous 2024/2025 keys this
    /// reproduces the former `>= 2025 → 2025`, else → 2024` mapping exactly.
    ///
    /// Deliberately a floor and not a nearest-match: rules enacted for a later
    /// year must never be applied to an earlier one, so a table with a gap
    /// (say 2024 and 2030) resolves 2028 to 2024, not 2030.
    nonisolated static func resolvedFinancialYear(_ financialYear: Int, in years: [Int]) -> Int {
        years.filter { $0 <= financialYear }.max() ?? years.min() ?? financialYear
    }

    nonisolated static func rules(for financialYear: Int) -> YearRules {
        let resolved = resolvedFinancialYear(financialYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    // MARK: - 2024 (FY 2024-25)

    nonisolated private static let year2024 = YearRules(
        ruleSetID: "IN_FY2024_25",
        newRegimeSlabs: [
            TaxSlab(lower: 0,         upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
            TaxSlab(lower: 300_000,   upper: 700_000,   ratePercent: 5,  label: "₹3L – ₹7L"),
            TaxSlab(lower: 700_000,   upper: 1_000_000, ratePercent: 10, label: "₹7L – ₹10L"),
            TaxSlab(lower: 1_000_000, upper: 1_200_000, ratePercent: 15, label: "₹10L – ₹12L"),
            TaxSlab(lower: 1_200_000, upper: 1_500_000, ratePercent: 20, label: "₹12L – ₹15L"),
            TaxSlab(lower: 1_500_000, upper: nil,       ratePercent: 30, label: "Above ₹15L"),
        ],
        oldRegimeByAge: OldRegimeByAge(
            regular: [
                TaxSlab(lower: 0,         upper: 250_000,   ratePercent: 0,  label: "₹0 – ₹2.5L"),
                TaxSlab(lower: 250_000,   upper: 500_000,   ratePercent: 5,  label: "₹2.5L – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ],
            senior: [
                TaxSlab(lower: 0,         upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
                TaxSlab(lower: 300_000,   upper: 500_000,   ratePercent: 5,  label: "₹3L – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ],
            superSenior: [
                TaxSlab(lower: 0,         upper: 500_000,   ratePercent: 0,  label: "₹0 – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ]
        ),
        newRegimeSalariedStandardDeduction: 75_000,
        oldRegimeSalariedStandardDeduction: 50_000,
        newRegimeRebate: RebateRules(threshold: 700_000, cap: 25_000),
        oldRegimeRebate: RebateRules(threshold: 500_000, cap: 12_500),
        surcharge: SurchargeRules(
            bands: [
                SurchargeBand(threshold:   50_00_000, newRegimeRate: 10, oldRegimeRate: 10),
                SurchargeBand(threshold: 1_00_00_000, newRegimeRate: 15, oldRegimeRate: 15),
                SurchargeBand(threshold: 2_00_00_000, newRegimeRate: 25, oldRegimeRate: 25),
                SurchargeBand(threshold: 5_00_00_000, newRegimeRate: 25, oldRegimeRate: 37),
            ],
            specialRateCap: Decimal(15),
            specialRateCapWarningThreshold: 1_00_00_000
        ),
        cessRate: Decimal(sign: .plus, exponent: -2, significand: 4),
        equityLTCGRate: Decimal(sign: .plus, exponent: -3, significand: 125),
        equityLTCGExemption: 125_000,
        equitySTCGRate: Decimal(sign: .plus, exponent: -1, significand: 2)
    )

    // MARK: - 2025 (FY 2025-26)

    nonisolated private static let year2025 = YearRules(
        ruleSetID: "IN_FY2025_26",
        newRegimeSlabs: [
            TaxSlab(lower: 0,         upper: 400_000,   ratePercent: 0,  label: "₹0 – ₹4L"),
            TaxSlab(lower: 400_000,   upper: 800_000,   ratePercent: 5,  label: "₹4L – ₹8L"),
            TaxSlab(lower: 800_000,   upper: 1_200_000, ratePercent: 10, label: "₹8L – ₹12L"),
            TaxSlab(lower: 1_200_000, upper: 1_600_000, ratePercent: 15, label: "₹12L – ₹16L"),
            TaxSlab(lower: 1_600_000, upper: 2_000_000, ratePercent: 20, label: "₹16L – ₹20L"),
            TaxSlab(lower: 2_000_000, upper: 2_400_000, ratePercent: 25, label: "₹20L – ₹24L"),
            TaxSlab(lower: 2_400_000, upper: nil,       ratePercent: 30, label: "Above ₹24L"),
        ],
        oldRegimeByAge: OldRegimeByAge(
            regular: [
                TaxSlab(lower: 0,         upper: 250_000,   ratePercent: 0,  label: "₹0 – ₹2.5L"),
                TaxSlab(lower: 250_000,   upper: 500_000,   ratePercent: 5,  label: "₹2.5L – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ],
            senior: [
                TaxSlab(lower: 0,         upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
                TaxSlab(lower: 300_000,   upper: 500_000,   ratePercent: 5,  label: "₹3L – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ],
            superSenior: [
                TaxSlab(lower: 0,         upper: 500_000,   ratePercent: 0,  label: "₹0 – ₹5L"),
                TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
            ]
        ),
        newRegimeSalariedStandardDeduction: 75_000,
        oldRegimeSalariedStandardDeduction: 50_000,
        newRegimeRebate: RebateRules(threshold: 1_200_000, cap: 60_000),
        oldRegimeRebate: RebateRules(threshold: 500_000, cap: 12_500),
        surcharge: SurchargeRules(
            bands: [
                SurchargeBand(threshold:   50_00_000, newRegimeRate: 10, oldRegimeRate: 10),
                SurchargeBand(threshold: 1_00_00_000, newRegimeRate: 15, oldRegimeRate: 15),
                SurchargeBand(threshold: 2_00_00_000, newRegimeRate: 25, oldRegimeRate: 25),
                SurchargeBand(threshold: 5_00_00_000, newRegimeRate: 25, oldRegimeRate: 37),
            ],
            specialRateCap: Decimal(15),
            specialRateCapWarningThreshold: 1_00_00_000
        ),
        cessRate: Decimal(sign: .plus, exponent: -2, significand: 4),
        equityLTCGRate: Decimal(sign: .plus, exponent: -3, significand: 125),
        equityLTCGExemption: 125_000,
        equitySTCGRate: Decimal(sign: .plus, exponent: -1, significand: 2)
    )
}
