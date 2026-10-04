import Foundation
import VittoraCore

/// In-binary Australian resident income-tax rule table keyed by tax year
/// (the July-start year). Adding a future year is a pure data edit here.
///
/// Every figure is a statutory value for its year (2025-26, 2026-27). Nothing
/// is projected: a year Vittora does not hold resolves to the latest held year
/// not after it, and the estimate says so.
enum AUTaxRuleTable {

    /// Medicare levy for a single person: the lesser of 2% of taxable income
    /// and 10% of the income above the low-income threshold. No separate upper
    /// threshold is stored, so there is no rounding cliff where they meet.
    struct MedicareLevyRules: Sendable {
        /// No levy at or below this.
        let lowerThreshold: Decimal
        let ratePercent: Decimal
        let shadeInRatePercent: Decimal
    }

    /// Medicare levy surcharge: charged only to those WITHOUT private hospital
    /// cover, on a three-tier ladder.
    struct SurchargeTier: Sendable {
        let threshold: Decimal
        let ratePercent: Decimal
    }

    /// Low Income Tax Offset. A non-refundable offset, so it can reduce tax to
    /// nil but never below it — modelled explicitly rather than as a deduction.
    struct LITORules: Sendable {
        let maximumOffset: Decimal
        let firstTaperThreshold: Decimal
        let firstTaperRatePercent: Decimal
        let secondTaperThreshold: Decimal
        let secondTaperRatePercent: Decimal
        let cutOut: Decimal
    }

    struct SuperannuationRules: Sendable {
        let guaranteeRatePercent: Decimal
        let concessionalCap: Decimal
    }

    struct CapitalGainsRules: Sendable {
        /// Assets held more than 12 months get half the gain taxed.
        let discountPercent: Decimal
    }

    struct YearRules: Sendable {
        let ruleSetID: String
        let brackets: [TaxSlab]
        let medicareLevy: MedicareLevyRules
        /// Ascending by threshold; the applicable tier is the last one exceeded.
        let surchargeTiers: [SurchargeTier]
        let lito: LITORules
        let superannuation: SuperannuationRules
        let capitalGains: CapitalGainsRules
    }

    private struct Entry: Sendable {
        let year: Int
        let rules: YearRules
    }

    nonisolated private static let entries: [Entry] = [
        Entry(year: 2025, rules: year2025),
        Entry(year: 2026, rules: year2026),
    ]

    nonisolated static var supportedYears: [Int] { entries.map(\.year) }

    nonisolated static func rules(for taxYear: Int) -> YearRules {
        let resolved = resolvedTaxYear(taxYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    /// The latest held year not after the request (the earliest, before the
    /// table) — a later year's rules are never applied to an earlier one, and
    /// nothing is extrapolated.
    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        available.filter { $0 <= requested }.max() ?? available.min() ?? requested
    }

    // MARK: - 2025 (tax year 2025-26, 1 July 2025 to 30 June 2026)

    nonisolated private static let year2025 = YearRules(
        ruleSetID: "AU_TY2025_26",
        brackets: [
            TaxSlab(lower: 0,       upper: 18_200,  ratePercent: 0,  label: "Tax-free threshold"),
            TaxSlab(lower: 18_200,  upper: 45_000,  ratePercent: 16, label: "16%"),
            TaxSlab(lower: 45_000,  upper: 135_000, ratePercent: 30, label: "30%"),
            TaxSlab(lower: 135_000, upper: 190_000, ratePercent: 37, label: "37%"),
            TaxSlab(lower: 190_000, upper: nil,     ratePercent: 45, label: "45%"),
        ],
        // $28,011 for 2025-26 and later: Treasury Laws Amendment (2026 Measures
        // No. 2) Act 2026, Sch 5. ($27,222 was the 2024-25 figure.)
        medicareLevy: MedicareLevyRules(
            lowerThreshold: 28_011,
            ratePercent: 2,
            shadeInRatePercent: 10
        ),
        surchargeTiers: [
            SurchargeTier(threshold: 101_000, ratePercent: 1),
            SurchargeTier(threshold: 118_000, ratePercent: Decimal(string: "1.25") ?? 0),
            SurchargeTier(threshold: 158_000, ratePercent: Decimal(string: "1.5") ?? 0),
        ],
        lito: LITORules(
            maximumOffset: 700,
            firstTaperThreshold: 37_500,
            firstTaperRatePercent: 5,
            secondTaperThreshold: 45_000,
            secondTaperRatePercent: Decimal(string: "1.5") ?? 0,
            cutOut: 66_667
        ),
        superannuation: SuperannuationRules(
            guaranteeRatePercent: 12,
            concessionalCap: 30_000
        ),
        capitalGains: CapitalGainsRules(
            discountPercent: 50
        )
    )

    // MARK: - 2026 (tax year 2026-27, 1 July 2026 to 30 June 2027)

    /// The 16% rate becomes 15% from 1 July 2026 (Income Tax Rates Act, as
    /// amended 2025; 14% follows in 2027-28). MLS tiers are re-indexed and the
    /// concessional cap rises to $32,500. Medicare's $28,011 threshold carries
    /// forward until a later year is legislated.
    nonisolated private static let year2026 = YearRules(
        ruleSetID: "AU_TY2026_27",
        brackets: [
            TaxSlab(lower: 0,       upper: 18_200,  ratePercent: 0,  label: "Tax-free threshold"),
            TaxSlab(lower: 18_200,  upper: 45_000,  ratePercent: 15, label: "15%"),
            TaxSlab(lower: 45_000,  upper: 135_000, ratePercent: 30, label: "30%"),
            TaxSlab(lower: 135_000, upper: 190_000, ratePercent: 37, label: "37%"),
            TaxSlab(lower: 190_000, upper: nil,     ratePercent: 45, label: "45%"),
        ],
        medicareLevy: MedicareLevyRules(
            lowerThreshold: 28_011,
            ratePercent: 2,
            shadeInRatePercent: 10
        ),
        surchargeTiers: [
            SurchargeTier(threshold: 105_000, ratePercent: 1),
            SurchargeTier(threshold: 123_000, ratePercent: Decimal(string: "1.25") ?? 0),
            SurchargeTier(threshold: 164_000, ratePercent: Decimal(string: "1.5") ?? 0),
        ],
        lito: LITORules(
            maximumOffset: 700,
            firstTaperThreshold: 37_500,
            firstTaperRatePercent: 5,
            secondTaperThreshold: 45_000,
            secondTaperRatePercent: Decimal(string: "1.5") ?? 0,
            cutOut: 66_667
        ),
        superannuation: SuperannuationRules(
            guaranteeRatePercent: 12,
            concessionalCap: 32_500
        ),
        capitalGains: CapitalGainsRules(
            discountPercent: 50
        )
    )
}
