import Foundation
import VittoraCore

/// In-binary Australian resident income-tax rule table keyed by tax year
/// (the July-start year). Adding a future year is a pure data edit here.
///
/// Every figure is a statutory 2025-26 value. Nothing is projected: a year
/// Vittora does not hold resolves to the nearest year it does, and the estimate
/// says which rule set produced it.
enum AUTaxRuleTable {

    /// Medicare levy. Charged on taxable income, with a phase-in for low incomes
    /// so that crossing the threshold does not create a cliff.
    struct MedicareLevyRules: Sendable {
        /// No levy at or below this.
        let lowerThreshold: Decimal
        /// Full 2% applies from here up.
        let upperThreshold: Decimal
        let ratePercent: Decimal
        /// Within the phase-in the levy is this share of income above the lower
        /// threshold, which is what makes the two thresholds meet exactly.
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
        Entry(year: 2025, rules: year2025)
    ]

    nonisolated static var supportedYears: [Int] { entries.map(\.year) }

    nonisolated static func rules(for taxYear: Int) -> YearRules {
        let resolved = resolvedTaxYear(taxYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    /// Clamps to the nearest held year rather than extrapolating — a projected
    /// bracket is indistinguishable from a statutory one once it is in the UI.
    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        guard let lowest = available.min(), let highest = available.max() else { return requested }
        if requested < lowest { return lowest }
        if requested > highest { return highest }
        return available.contains(requested) ? requested : highest
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
        // NOTE: the two threshold sets below are indexed annually and carry LESS
        // confidence than the brackets above, which are legislated and stable.
        // They are flagged for owner verification against the ATO before release.
        // Brackets, LITO, the CGT discount, the 12% super guarantee and the
        // $30,000 concessional cap are high confidence.
        medicareLevy: MedicareLevyRules(
            lowerThreshold: 27_222,
            upperThreshold: 34_027,
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
}
