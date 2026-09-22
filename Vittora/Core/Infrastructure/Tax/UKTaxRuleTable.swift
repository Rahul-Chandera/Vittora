import Foundation
import VittoraCore

/// In-binary UK income-tax rule table keyed by tax year (the April-start year).
/// Adding a future year is a pure data edit here — no calculator logic changes.
///
/// Every figure below is a statutory 2025-26 value. Nothing is projected or
/// inferred: a year Vittora does not hold is resolved to the nearest year it
/// does, and the estimate says which rule set produced it.
enum UKTaxRuleTable {

    /// Bands for non-savings, non-dividend income. Scotland sets its own; the rest
    /// of the UK shares one set. Savings and dividend income use the UK-wide rates
    /// in `YearRules` regardless of where the taxpayer lives, which is why those
    /// rates are not in here.
    struct RegionBands: Sendable {
        /// Applied to taxable income, i.e. after the personal allowance.
        let bands: [TaxSlab]
        /// The top marginal rate, used for the marginal-rate line.
        let topRatePercent: Decimal
        /// Income (not taxable income) above which the additional/top rate starts.
        /// Needed for the savings-allowance tiering, which keys off the band the
        /// taxpayer lands in rather than off the numbers themselves.
        let higherRateThreshold: Decimal
        let topRateThreshold: Decimal
    }

    struct NationalInsuranceRules: Sendable {
        /// Class 1 employee: nothing below this.
        let primaryThreshold: Decimal
        /// Above this the rate drops to `upperRate`.
        let upperEarningsLimit: Decimal
        let mainRate: Decimal
        let upperRate: Decimal
        /// Class 4 self-employed main rate over the same thresholds. Class 2 is not
        /// modelled: it stopped being a mandatory charge in 2024-25 and is now
        /// voluntary, so charging it would overstate a self-employed bill.
        let selfEmployedMainRate: Decimal
        let selfEmployedUpperRate: Decimal
    }

    struct DividendRules: Sendable {
        let allowance: Decimal
        let basicRate: Decimal
        let higherRate: Decimal
        let additionalRate: Decimal
    }

    struct SavingsRules: Sendable {
        /// 0% band for savings income, available only to the extent that
        /// non-savings income does not already fill it.
        let startingRateBand: Decimal
        /// Personal Savings Allowance, by the band the taxpayer lands in.
        let allowanceBasicRate: Decimal
        let allowanceHigherRate: Decimal
        let allowanceAdditionalRate: Decimal
    }

    struct CapitalGainsRules: Sendable {
        let annualExemptAmount: Decimal
        let basicRate: Decimal
        let higherRate: Decimal
    }

    struct YearRules: Sendable {
        let ruleSetID: String
        let personalAllowance: Decimal
        /// The allowance is reduced by £1 for every £2 of income above this.
        let personalAllowanceTaperThreshold: Decimal
        /// £2 of income removes £1 of allowance.
        let personalAllowanceTaperRatio: Decimal
        let restOfUK: RegionBands
        let scotland: RegionBands
        let nationalInsurance: NationalInsuranceRules
        let dividends: DividendRules
        let savings: SavingsRules
        let capitalGains: CapitalGainsRules

        nonisolated func regionBands(isScottishTaxpayer: Bool) -> RegionBands {
            isScottishTaxpayer ? scotland : restOfUK
        }
    }

    private struct Entry: Sendable {
        let year: Int
        let rules: YearRules
    }

    /// Ascending by year.
    nonisolated private static let entries: [Entry] = [
        Entry(year: 2025, rules: year2025)
    ]

    nonisolated static var supportedYears: [Int] { entries.map(\.year) }

    nonisolated static func rules(for taxYear: Int) -> YearRules {
        let resolved = resolvedTaxYear(taxYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    /// Clamps to the nearest held year rather than extrapolating. A projected band
    /// would be indistinguishable from a statutory one in the UI.
    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        guard let lowest = available.min(), let highest = available.max() else { return requested }
        if requested < lowest { return lowest }
        if requested > highest { return highest }
        return available.contains(requested) ? requested : highest
    }

    // MARK: - 2025 (tax year 2025-26, 6 April 2025 to 5 April 2026)

    nonisolated private static let year2025 = YearRules(
        ruleSetID: "UK_TY2025_26",
        personalAllowance: 12_570,
        personalAllowanceTaperThreshold: 100_000,
        personalAllowanceTaperRatio: 2,

        // England, Wales and Northern Ireland. Bands are on taxable income, so the
        // £37,700 basic-rate limit sits on top of the £12,570 allowance to give the
        // familiar £50,270 higher-rate threshold.
        restOfUK: RegionBands(
            bands: [
                TaxSlab(lower: 0,       upper: 37_700,  ratePercent: 20, label: "Basic rate"),
                TaxSlab(lower: 37_700,  upper: 112_570, ratePercent: 40, label: "Higher rate"),
                TaxSlab(lower: 112_570, upper: nil,     ratePercent: 45, label: "Additional rate"),
            ],
            topRatePercent: 45,
            higherRateThreshold: 50_270,
            topRateThreshold: 125_140
        ),

        // Scotland sets six bands on non-savings, non-dividend income. The band
        // edges below are taxable-income figures; the gross equivalents are
        // £15,397 / £27,491 / £43,662 / £75,000 / £125,140.
        scotland: RegionBands(
            bands: [
                TaxSlab(lower: 0,       upper: 2_827,   ratePercent: 19, label: "Starter rate"),
                TaxSlab(lower: 2_827,   upper: 14_921,  ratePercent: 20, label: "Basic rate"),
                TaxSlab(lower: 14_921,  upper: 31_092,  ratePercent: 21, label: "Intermediate rate"),
                TaxSlab(lower: 31_092,  upper: 62_430,  ratePercent: 42, label: "Higher rate"),
                TaxSlab(lower: 62_430,  upper: 112_570, ratePercent: 45, label: "Advanced rate"),
                TaxSlab(lower: 112_570, upper: nil,     ratePercent: 48, label: "Top rate"),
            ],
            topRatePercent: 48,
            higherRateThreshold: 43_662,
            topRateThreshold: 125_140
        ),

        nationalInsurance: NationalInsuranceRules(
            primaryThreshold: 12_570,
            upperEarningsLimit: 50_270,
            mainRate: 8,
            upperRate: 2,
            selfEmployedMainRate: 6,
            selfEmployedUpperRate: 2
        ),

        dividends: DividendRules(
            allowance: 500,
            basicRate: Decimal(string: "8.75") ?? 0,
            higherRate: Decimal(string: "33.75") ?? 0,
            additionalRate: Decimal(string: "39.35") ?? 0
        ),

        savings: SavingsRules(
            startingRateBand: 5_000,
            allowanceBasicRate: 1_000,
            allowanceHigherRate: 500,
            allowanceAdditionalRate: 0
        ),

        capitalGains: CapitalGainsRules(
            annualExemptAmount: 3_000,
            basicRate: 18,
            higherRate: 24
        )
    )
}
