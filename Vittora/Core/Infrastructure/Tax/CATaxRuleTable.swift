import Foundation
import VittoraCore

/// Canadian federal and provincial/territorial rule table for tax year 2025.
///
/// # Confidence
///
/// **Federal figures and contribution mechanics are high confidence.** Brackets,
/// the basic personal amount and its taper, CPP/CPP2, EI, and the Quebec
/// abatement are legislated and stable.
///
/// **Every provincial and territorial table below is FLAGGED FOR VERIFICATION.**
/// All thirteen index their brackets and basic personal amounts annually, and a
/// wrong bracket here is a wrong number for everyone in that province — not a
/// rounding difference. They were derived rather than sourced, and the owner
/// checks them before release. Each is marked `// VERIFY` for that reason.
///
/// Adding a year, or correcting a province, is a pure data edit.
enum CATaxRuleTable {

    /// One jurisdiction's income-tax table: brackets plus its own basic personal
    /// amount, which is a credit at the lowest rate rather than a deduction.
    struct Jurisdiction: Sendable {
        let brackets: [TaxSlab]
        let basicPersonalAmount: Decimal
        /// The rate the non-refundable credits are valued at — the lowest bracket.
        let creditRatePercent: Decimal
        /// Ontario and PEI charge a surtax on their own tax. Empty elsewhere.
        var surtaxes: [Surtax] = []
    }

    /// A surtax is charged on provincial tax, not on income, so it stacks after
    /// credits rather than alongside the brackets.
    struct Surtax: Sendable {
        let threshold: Decimal
        let ratePercent: Decimal
    }

    /// Canada Pension Plan. Two tiers since 2024: the base contribution up to the
    /// year's maximum pensionable earnings, then CPP2 on the band above it.
    struct CPPRules: Sendable {
        let basicExemption: Decimal
        let maximumPensionableEarnings: Decimal
        let ratePercent: Decimal
        /// CPP2 applies between YMPE and this.
        let additionalMaximumPensionableEarnings: Decimal
        let additionalRatePercent: Decimal
    }

    struct EIRules: Sendable {
        let maximumInsurableEarnings: Decimal
        let ratePercent: Decimal
        /// Quebec pays a lower EI rate because QPIP covers parental benefits.
        let quebecRatePercent: Decimal
    }

    struct YearRules: Sendable {
        let ruleSetID: String
        let federal: Jurisdiction
        /// The federal BPA is clawed back across the top brackets; this is the
        /// floor it tapers down to.
        let federalBasicPersonalAmountMinimum: Decimal
        let federalBPATaperStart: Decimal
        let federalBPATaperEnd: Decimal
        let provinces: [CAProvince: Jurisdiction]
        let cpp: CPPRules
        let ei: EIRules
        /// Quebec residents reduce basic federal tax by this share, because
        /// Quebec administers programmes Ottawa funds elsewhere. Missing it
        /// overstates a Quebec bill badly.
        let quebecAbatementPercent: Decimal
        /// Half of a capital gain is taxable.
        let capitalGainsInclusionPercent: Decimal
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

    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        guard let lowest = available.min(), let highest = available.max() else { return requested }
        if requested < lowest { return lowest }
        if requested > highest { return highest }
        return available.contains(requested) ? requested : highest
    }

    /// nonisolated: used from nonisolated static lets under the app target's
    /// MainActor-by-default actor isolation.
    nonisolated private static func d(_ value: String) -> Decimal { Decimal(string: value) ?? 0 }

    // MARK: - 2025

    nonisolated private static let year2025 = YearRules(
        ruleSetID: "CA_TY2025",

        // The lowest federal rate was cut from 15% to 14% part-way through 2025,
        // so the year's effective lowest rate is the blended 14.5%. Using either
        // 15% or 14% alone is wrong for 2025 specifically.
        federal: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 57_375,  ratePercent: d("14.5"), label: "14.5%"),
                TaxSlab(lower: 57_375,  upper: 114_750, ratePercent: d("20.5"), label: "20.5%"),
                TaxSlab(lower: 114_750, upper: 177_882, ratePercent: 26,        label: "26%"),
                TaxSlab(lower: 177_882, upper: 253_414, ratePercent: 29,        label: "29%"),
                TaxSlab(lower: 253_414, upper: nil,     ratePercent: 33,        label: "33%"),
            ],
            basicPersonalAmount: 16_129,
            creditRatePercent: d("14.5")
        ),
        federalBasicPersonalAmountMinimum: 14_538,
        federalBPATaperStart: 177_882,
        federalBPATaperEnd: 253_414,

        provinces: provinces2025,

        cpp: CPPRules(
            basicExemption: 3_500,
            maximumPensionableEarnings: 71_300,
            ratePercent: d("5.95"),
            additionalMaximumPensionableEarnings: 81_200,
            additionalRatePercent: 4
        ),
        ei: EIRules(
            maximumInsurableEarnings: 65_700,
            ratePercent: d("1.64"),
            quebecRatePercent: d("1.31")
        ),
        quebecAbatementPercent: d("16.5"),
        capitalGainsInclusionPercent: 50
    )

    // MARK: - Provinces and territories (ALL VERIFY)

    nonisolated private static let provinces2025: [CAProvince: Jurisdiction] = [
        // VERIFY — Alberta added an 8% bracket in 2025.
        .alberta: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 60_000,  ratePercent: 8,  label: "8%"),
                TaxSlab(lower: 60_000,  upper: 151_234, ratePercent: 10, label: "10%"),
                TaxSlab(lower: 151_234, upper: 181_481, ratePercent: 12, label: "12%"),
                TaxSlab(lower: 181_481, upper: 241_974, ratePercent: 13, label: "13%"),
                TaxSlab(lower: 241_974, upper: 362_961, ratePercent: 14, label: "14%"),
                TaxSlab(lower: 362_961, upper: nil,     ratePercent: 15, label: "15%"),
            ],
            basicPersonalAmount: 22_323,
            creditRatePercent: 8
        ),
        // VERIFY
        .britishColumbia: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 49_279,  ratePercent: d("5.06"),  label: "5.06%"),
                TaxSlab(lower: 49_279,  upper: 98_560,  ratePercent: d("7.7"),   label: "7.7%"),
                TaxSlab(lower: 98_560,  upper: 113_158, ratePercent: d("10.5"),  label: "10.5%"),
                TaxSlab(lower: 113_158, upper: 137_407, ratePercent: d("12.29"), label: "12.29%"),
                TaxSlab(lower: 137_407, upper: 186_306, ratePercent: d("14.7"),  label: "14.7%"),
                TaxSlab(lower: 186_306, upper: 259_829, ratePercent: d("16.8"),  label: "16.8%"),
                TaxSlab(lower: 259_829, upper: nil,     ratePercent: d("20.5"),  label: "20.5%"),
            ],
            basicPersonalAmount: 12_932,
            creditRatePercent: d("5.06")
        ),
        // VERIFY
        .manitoba: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 47_564,  ratePercent: d("10.8"),  label: "10.8%"),
                TaxSlab(lower: 47_564,  upper: 101_200, ratePercent: d("12.75"), label: "12.75%"),
                TaxSlab(lower: 101_200, upper: nil,     ratePercent: d("17.4"),  label: "17.4%"),
            ],
            basicPersonalAmount: 15_969,
            creditRatePercent: d("10.8")
        ),
        // VERIFY
        .newBrunswick: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 51_306,  ratePercent: d("9.4"),  label: "9.4%"),
                TaxSlab(lower: 51_306,  upper: 102_614, ratePercent: 14,        label: "14%"),
                TaxSlab(lower: 102_614, upper: 190_060, ratePercent: 16,        label: "16%"),
                TaxSlab(lower: 190_060, upper: nil,     ratePercent: d("19.5"), label: "19.5%"),
            ],
            basicPersonalAmount: 13_396,
            creditRatePercent: d("9.4")
        ),
        // VERIFY — NL has eight brackets, the most of any province.
        .newfoundlandAndLabrador: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,         upper: 44_192,    ratePercent: d("8.7"),  label: "8.7%"),
                TaxSlab(lower: 44_192,    upper: 88_382,    ratePercent: d("14.5"), label: "14.5%"),
                TaxSlab(lower: 88_382,    upper: 157_792,   ratePercent: d("15.8"), label: "15.8%"),
                TaxSlab(lower: 157_792,   upper: 220_910,   ratePercent: d("17.8"), label: "17.8%"),
                TaxSlab(lower: 220_910,   upper: 282_214,   ratePercent: d("19.8"), label: "19.8%"),
                TaxSlab(lower: 282_214,   upper: 564_429,   ratePercent: d("20.8"), label: "20.8%"),
                TaxSlab(lower: 564_429,   upper: 1_128_858, ratePercent: d("21.3"), label: "21.3%"),
                TaxSlab(lower: 1_128_858, upper: nil,       ratePercent: d("21.8"), label: "21.8%"),
            ],
            basicPersonalAmount: 11_067,
            creditRatePercent: d("8.7")
        ),
        // VERIFY
        .northwestTerritories: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 51_964,  ratePercent: d("5.9"),   label: "5.9%"),
                TaxSlab(lower: 51_964,  upper: 103_930, ratePercent: d("8.6"),   label: "8.6%"),
                TaxSlab(lower: 103_930, upper: 168_967, ratePercent: d("12.2"),  label: "12.2%"),
                TaxSlab(lower: 168_967, upper: nil,     ratePercent: d("14.05"), label: "14.05%"),
            ],
            basicPersonalAmount: 17_842,
            creditRatePercent: d("5.9")
        ),
        // VERIFY
        .novaScotia: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 30_507,  ratePercent: d("8.79"),  label: "8.79%"),
                TaxSlab(lower: 30_507,  upper: 61_015,  ratePercent: d("14.95"), label: "14.95%"),
                TaxSlab(lower: 61_015,  upper: 95_883,  ratePercent: d("16.67"), label: "16.67%"),
                TaxSlab(lower: 95_883,  upper: 154_650, ratePercent: d("17.5"),  label: "17.5%"),
                TaxSlab(lower: 154_650, upper: nil,     ratePercent: 21,         label: "21%"),
            ],
            basicPersonalAmount: 11_744,
            creditRatePercent: d("8.79")
        ),
        // VERIFY
        .nunavut: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 54_707,  ratePercent: 4,         label: "4%"),
                TaxSlab(lower: 54_707,  upper: 109_413, ratePercent: 7,         label: "7%"),
                TaxSlab(lower: 109_413, upper: 177_881, ratePercent: 9,         label: "9%"),
                TaxSlab(lower: 177_881, upper: nil,     ratePercent: d("11.5"), label: "11.5%"),
            ],
            basicPersonalAmount: 19_274,
            creditRatePercent: 4
        ),
        // VERIFY — Ontario is the only jurisdiction with TWO surtaxes.
        .ontario: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 52_886,  ratePercent: d("5.05"),  label: "5.05%"),
                TaxSlab(lower: 52_886,  upper: 105_775, ratePercent: d("9.15"),  label: "9.15%"),
                TaxSlab(lower: 105_775, upper: 150_000, ratePercent: d("11.16"), label: "11.16%"),
                TaxSlab(lower: 150_000, upper: 220_000, ratePercent: d("12.16"), label: "12.16%"),
                TaxSlab(lower: 220_000, upper: nil,     ratePercent: d("13.16"), label: "13.16%"),
            ],
            basicPersonalAmount: 12_747,
            creditRatePercent: d("5.05"),
            surtaxes: [
                Surtax(threshold: 5_710, ratePercent: 20),
                Surtax(threshold: 7_307, ratePercent: 36),
            ]
        ),
        // VERIFY — PEI has one surtax.
        .princeEdwardIsland: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 33_328,  ratePercent: d("9.5"),   label: "9.5%"),
                TaxSlab(lower: 33_328,  upper: 64_656,  ratePercent: d("13.47"), label: "13.47%"),
                TaxSlab(lower: 64_656,  upper: 105_000, ratePercent: d("16.6"),  label: "16.6%"),
                TaxSlab(lower: 105_000, upper: 140_000, ratePercent: d("17.62"), label: "17.62%"),
                TaxSlab(lower: 140_000, upper: nil,     ratePercent: 19,         label: "19%"),
            ],
            basicPersonalAmount: 14_250,
            creditRatePercent: d("9.5")
        ),
        // VERIFY — Quebec also gets the federal abatement, handled in the calculator.
        .quebec: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 53_255,  ratePercent: 14,         label: "14%"),
                TaxSlab(lower: 53_255,  upper: 106_495, ratePercent: 19,         label: "19%"),
                TaxSlab(lower: 106_495, upper: 129_590, ratePercent: 24,         label: "24%"),
                TaxSlab(lower: 129_590, upper: nil,     ratePercent: d("25.75"), label: "25.75%"),
            ],
            basicPersonalAmount: 18_571,
            creditRatePercent: 14
        ),
        // VERIFY
        .saskatchewan: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 53_463,  ratePercent: d("10.5"), label: "10.5%"),
                TaxSlab(lower: 53_463,  upper: 152_750, ratePercent: d("12.5"), label: "12.5%"),
                TaxSlab(lower: 152_750, upper: nil,     ratePercent: d("14.5"), label: "14.5%"),
            ],
            basicPersonalAmount: 18_991,
            creditRatePercent: d("10.5")
        ),
        // VERIFY — Yukon mirrors the federal bracket edges.
        .yukon: Jurisdiction(
            brackets: [
                TaxSlab(lower: 0,       upper: 57_375,  ratePercent: d("6.4"),  label: "6.4%"),
                TaxSlab(lower: 57_375,  upper: 114_750, ratePercent: 9,         label: "9%"),
                TaxSlab(lower: 114_750, upper: 177_882, ratePercent: d("10.9"), label: "10.9%"),
                TaxSlab(lower: 177_882, upper: 500_000, ratePercent: d("12.8"), label: "12.8%"),
                TaxSlab(lower: 500_000, upper: nil,     ratePercent: 15,        label: "15%"),
            ],
            basicPersonalAmount: 16_129,
            creditRatePercent: d("6.4")
        ),
    ]
}
