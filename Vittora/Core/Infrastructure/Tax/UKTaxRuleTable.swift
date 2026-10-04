import Foundation
import VittoraCore

/// In-binary UK income-tax rule table keyed by tax year (the April-start year).
/// Adding a future year is a pure data edit here — no calculator logic changes.
///
/// Every figure below is a statutory value for its year (2025-26, 2026-27).
/// Nothing is projected: a year Vittora does not hold resolves to the latest
/// held year not after it (or the earliest, before the table), and the
/// estimate says so.
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
        Entry(year: 2025, rules: year2025),
        Entry(year: 2026, rules: year2026),
    ]

    nonisolated static var supportedYears: [Int] { entries.map(\.year) }

    nonisolated static func rules(for taxYear: Int) -> YearRules {
        let resolved = resolvedTaxYear(taxYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    /// The latest held year not after the request, so a later year's rules are
    /// never applied to an earlier year; before the table, the earliest. Never
    /// extrapolated — a projected band would look statutory in the UI.
    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        available.filter { $0 <= requested }.max() ?? available.min() ?? requested
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
                // The additional-rate edge is £125,140 of TAXABLE income: by then
                // the allowance has tapered to nil, so nothing is subtracted.
                TaxSlab(lower: 37_700,  upper: 125_140, ratePercent: 40, label: "Higher rate"),
                TaxSlab(lower: 125_140, upper: nil,     ratePercent: 45, label: "Additional rate"),
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
                TaxSlab(lower: 62_430,  upper: 125_140, ratePercent: 45, label: "Advanced rate"),
                TaxSlab(lower: 125_140, upper: nil,     ratePercent: 48, label: "Top rate"),
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

    // MARK: - 2026 (tax year 2026-27, 6 April 2026 to 5 April 2027)

    /// Changes from 2025-26 (Finance Act 2026; Scottish Rate Resolution 2026):
    /// dividend basic and higher rates rise to 10.75% and 35.75%, and Scotland
    /// widens its starter and basic bands (gross £16,537 / £29,526). The personal
    /// allowance, rUK bands, NI, savings and CGT figures are unchanged.
    nonisolated private static let year2026 = YearRules(
        ruleSetID: "UK_TY2026_27",
        personalAllowance: 12_570,
        personalAllowanceTaperThreshold: 100_000,
        personalAllowanceTaperRatio: 2,
        restOfUK: RegionBands(
            bands: [
                TaxSlab(lower: 0,       upper: 37_700,  ratePercent: 20, label: "Basic rate"),
                TaxSlab(lower: 37_700,  upper: 125_140, ratePercent: 40, label: "Higher rate"),
                TaxSlab(lower: 125_140, upper: nil,     ratePercent: 45, label: "Additional rate"),
            ],
            topRatePercent: 45,
            higherRateThreshold: 50_270,
            topRateThreshold: 125_140
        ),
        scotland: RegionBands(
            bands: [
                TaxSlab(lower: 0,       upper: 3_967,   ratePercent: 19, label: "Starter rate"),
                TaxSlab(lower: 3_967,   upper: 16_956,  ratePercent: 20, label: "Basic rate"),
                TaxSlab(lower: 16_956,  upper: 31_092,  ratePercent: 21, label: "Intermediate rate"),
                TaxSlab(lower: 31_092,  upper: 62_430,  ratePercent: 42, label: "Higher rate"),
                TaxSlab(lower: 62_430,  upper: 125_140, ratePercent: 45, label: "Advanced rate"),
                TaxSlab(lower: 125_140, upper: nil,     ratePercent: 48, label: "Top rate"),
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
            basicRate: Decimal(string: "10.75") ?? 0,
            higherRate: Decimal(string: "35.75") ?? 0,
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
