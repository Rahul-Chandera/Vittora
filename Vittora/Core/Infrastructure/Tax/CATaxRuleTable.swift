import Foundation
import VittoraCore

/// Canadian federal and provincial/territorial rule table, tax years 2025–2026.
///
/// # Provenance (checked 3 October 2026)
///
/// - Federal and provincial brackets: CRA "Canadian income tax rates for
///   individuals" (current and previous year); Quebec from Revenu Québec.
/// - Basic personal amounts: CRA line 30000 (2025); CRA T4127 Table 8.2 (2026).
/// - CPP/CPP2: CRA contribution rates and maximums; QPP: Revenu Québec.
/// - EI: Canada Employment Insurance Commission.
///
/// Two deliberate source choices:
/// - **Manitoba** froze its brackets ($47,000 / $100,000) and BPA ($15,780)
///   from 2025, with the BPA reduced to nil between $200,000 and $400,000 of net
///   income. CRA's general rate page still shows indexed figures; Manitoba's own
///   page and the annual MB428 form control the annual liability.
/// - **Newfoundland and Labrador 2026** BPA is $13,094 annually. CRA's July
///   payroll figure ($15,000) is a mid-year catch-up that delivers that annual
///   amount over half a year, not the annual return value.
///
/// Adding a year, or correcting a province, is a pure data edit.
enum CATaxRuleTable {

    /// How a jurisdiction's basic personal amount reduces with net income.
    enum BPAReduction: Sendable {
        case none
        /// Follows the federal BPA reduction (Yukon).
        case federal
        /// Linear from `maximum` at `start` to `minimum` at `end` (Manitoba).
        case linear(start: Decimal, end: Decimal, minimum: Decimal)
    }

    /// One jurisdiction's income-tax table: brackets plus its own basic personal
    /// amount, which is a credit at the lowest rate rather than a deduction.
    struct Jurisdiction: Sendable {
        let brackets: [TaxSlab]
        let basicPersonalAmount: Decimal
        /// The rate the non-refundable credits are valued at — the lowest bracket.
        let creditRatePercent: Decimal
        /// Ontario charges a surtax on its own tax. Empty elsewhere.
        var surtaxes: [Surtax] = []
        var bpaReduction: BPAReduction = .none
    }

    /// A surtax is charged on provincial tax, not on income, so it stacks after
    /// credits rather than alongside the brackets.
    struct Surtax: Sendable {
        let threshold: Decimal
        let ratePercent: Decimal
    }

    /// CPP or QPP. The first-tier rate is a BASE part (a tax credit) plus a
    /// 1% ENHANCED part (a deduction, line 22215); the second tier (CPP2/QPP2)
    /// is entirely enhanced.
    struct PensionPlanRules: Sendable {
        let basicExemption: Decimal
        let maximumPensionableEarnings: Decimal
        /// Employee first-tier rate, base + enhanced.
        let ratePercent: Decimal
        let enhancedRatePercent: Decimal
        /// Second tier applies between the YMPE and this.
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
        /// floor it tapers down to. Tested on NET income (line 23600).
        let federalBasicPersonalAmountMinimum: Decimal
        let federalBPATaperStart: Decimal
        let federalBPATaperEnd: Decimal
        let provinces: [CAProvince: Jurisdiction]
        let cpp: PensionPlanRules
        let qpp: PensionPlanRules
        let ei: EIRules
        /// Quebec residents reduce basic federal tax by this share.
        let quebecAbatementPercent: Decimal
        /// Half of a capital gain is taxable.
        let capitalGainsInclusionPercent: Decimal
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
    /// table): a later year's rules are never applied to an earlier year.
    nonisolated static func resolvedTaxYear(_ requested: Int, in available: [Int]) -> Int {
        available.filter { $0 <= requested }.max() ?? available.min() ?? requested
    }

    /// nonisolated: used from nonisolated static lets under the app target's
    /// MainActor-by-default actor isolation.
    nonisolated private static func d(_ value: String) -> Decimal { Decimal(string: value) ?? 0 }

    nonisolated private static func slabs(_ edges: [Decimal], _ rates: [String]) -> [TaxSlab] {
        var result: [TaxSlab] = []
        var lower: Decimal = 0
        for (index, rate) in rates.enumerated() {
            let upper: Decimal? = index < edges.count ? edges[index] : nil
            result.append(TaxSlab(lower: lower, upper: upper, ratePercent: d(rate), label: "\(rate)%"))
            lower = upper ?? lower
        }
        return result
    }

    // MARK: - 2025

    nonisolated private static let year2025 = YearRules(
        ruleSetID: "CA_TY2025",

        // The lowest federal rate was cut from 15% to 14% part-way through 2025,
        // so the year's annual lowest rate is the blended 14.5%.
        federal: Jurisdiction(
            brackets: slabs([57_375, 114_750, 177_882, 253_414], ["14.5", "20.5", "26", "29", "33"]),
            basicPersonalAmount: 16_129,
            creditRatePercent: d("14.5")
        ),
        federalBasicPersonalAmountMinimum: 14_538,
        federalBPATaperStart: 177_882,
        federalBPATaperEnd: 253_414,

        provinces: [
            .alberta: Jurisdiction(
                brackets: slabs([60_000, 151_234, 181_481, 241_974, 362_961], ["8", "10", "12", "13", "14", "15"]),
                basicPersonalAmount: 22_323, creditRatePercent: 8
            ),
            .britishColumbia: Jurisdiction(
                brackets: slabs([49_279, 98_560, 113_158, 137_407, 186_306, 259_829], ["5.06", "7.7", "10.5", "12.29", "14.7", "16.8", "20.5"]),
                basicPersonalAmount: 12_932, creditRatePercent: d("5.06")
            ),
            .manitoba: Jurisdiction(
                brackets: slabs([47_000, 100_000], ["10.8", "12.75", "17.4"]),
                basicPersonalAmount: 15_780, creditRatePercent: d("10.8"),
                bpaReduction: .linear(start: 200_000, end: 400_000, minimum: 0)
            ),
            .newBrunswick: Jurisdiction(
                brackets: slabs([51_306, 102_614, 190_060], ["9.4", "14", "16", "19.5"]),
                basicPersonalAmount: 13_396, creditRatePercent: d("9.4")
            ),
            .newfoundlandAndLabrador: Jurisdiction(
                brackets: slabs([44_192, 88_382, 157_792, 220_910, 282_214, 564_429, 1_128_858], ["8.7", "14.5", "15.8", "17.8", "19.8", "20.8", "21.3", "21.8"]),
                basicPersonalAmount: 11_067, creditRatePercent: d("8.7")
            ),
            .northwestTerritories: Jurisdiction(
                brackets: slabs([51_964, 103_930, 168_967], ["5.9", "8.6", "12.2", "14.05"]),
                basicPersonalAmount: 17_842, creditRatePercent: d("5.9")
            ),
            .novaScotia: Jurisdiction(
                brackets: slabs([30_507, 61_015, 95_883, 154_650], ["8.79", "14.95", "16.67", "17.5", "21"]),
                basicPersonalAmount: 11_744, creditRatePercent: d("8.79")
            ),
            .nunavut: Jurisdiction(
                brackets: slabs([54_707, 109_413, 177_881], ["4", "7", "9", "11.5"]),
                basicPersonalAmount: 19_274, creditRatePercent: 4
            ),
            .ontario: Jurisdiction(
                brackets: slabs([52_886, 105_775, 150_000, 220_000], ["5.05", "9.15", "11.16", "12.16", "13.16"]),
                basicPersonalAmount: 12_747, creditRatePercent: d("5.05"),
                surtaxes: [Surtax(threshold: 5_710, ratePercent: 20), Surtax(threshold: 7_307, ratePercent: 36)]
            ),
            .princeEdwardIsland: Jurisdiction(
                brackets: slabs([33_328, 64_656, 105_000, 140_000], ["9.5", "13.47", "16.6", "17.62", "19"]),
                basicPersonalAmount: 14_650, creditRatePercent: d("9.5")
            ),
            .quebec: Jurisdiction(
                brackets: slabs([53_255, 106_495, 129_590], ["14", "19", "24", "25.75"]),
                basicPersonalAmount: 18_571, creditRatePercent: 14
            ),
            .saskatchewan: Jurisdiction(
                brackets: slabs([53_463, 152_750], ["10.5", "12.5", "14.5"]),
                basicPersonalAmount: 19_491, creditRatePercent: d("10.5")
            ),
            .yukon: Jurisdiction(
                brackets: slabs([57_375, 114_750, 177_882, 500_000], ["6.4", "9", "10.9", "12.8", "15"]),
                basicPersonalAmount: 16_129, creditRatePercent: d("6.4"),
                bpaReduction: .federal
            ),
        ],

        cpp: PensionPlanRules(
            basicExemption: 3_500,
            maximumPensionableEarnings: 71_300,
            ratePercent: d("5.95"),
            enhancedRatePercent: 1,
            additionalMaximumPensionableEarnings: 81_200,
            additionalRatePercent: 4
        ),
        qpp: PensionPlanRules(
            basicExemption: 3_500,
            maximumPensionableEarnings: 71_300,
            ratePercent: d("6.40"),
            enhancedRatePercent: 1,
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

    // MARK: - 2026

    nonisolated private static let year2026 = YearRules(
        ruleSetID: "CA_TY2026",

        federal: Jurisdiction(
            brackets: slabs([58_523, 117_045, 181_440, 258_482], ["14", "20.5", "26", "29", "33"]),
            basicPersonalAmount: 16_452,
            creditRatePercent: 14
        ),
        federalBasicPersonalAmountMinimum: 14_829,
        federalBPATaperStart: 181_440,
        federalBPATaperEnd: 258_482,

        provinces: [
            .alberta: Jurisdiction(
                brackets: slabs([61_200, 154_259, 185_111, 246_813, 370_220], ["8", "10", "12", "13", "14", "15"]),
                basicPersonalAmount: 22_769, creditRatePercent: 8
            ),
            // BC's 2026 lowest ANNUAL rate is 5.60%.
            .britishColumbia: Jurisdiction(
                brackets: slabs([50_363, 100_728, 115_648, 140_430, 190_405, 265_545], ["5.6", "7.7", "10.5", "12.29", "14.7", "16.8", "20.5"]),
                basicPersonalAmount: 13_216, creditRatePercent: d("5.6")
            ),
            .manitoba: Jurisdiction(
                brackets: slabs([47_000, 100_000], ["10.8", "12.75", "17.4"]),
                basicPersonalAmount: 15_780, creditRatePercent: d("10.8"),
                bpaReduction: .linear(start: 200_000, end: 400_000, minimum: 0)
            ),
            .newBrunswick: Jurisdiction(
                brackets: slabs([52_333, 104_666, 193_861], ["9.4", "14", "16", "19.5"]),
                basicPersonalAmount: 13_664, creditRatePercent: d("9.4")
            ),
            .newfoundlandAndLabrador: Jurisdiction(
                brackets: slabs([44_678, 89_354, 159_528, 223_340, 285_319, 570_638, 1_141_275], ["8.7", "14.5", "15.8", "17.8", "19.8", "20.8", "21.3", "21.8"]),
                basicPersonalAmount: 13_094, creditRatePercent: d("8.7")
            ),
            .northwestTerritories: Jurisdiction(
                brackets: slabs([53_003, 106_009, 172_346], ["5.9", "8.6", "12.2", "14.05"]),
                basicPersonalAmount: 18_198, creditRatePercent: d("5.9")
            ),
            .novaScotia: Jurisdiction(
                brackets: slabs([30_995, 61_991, 97_417, 157_124], ["8.79", "14.95", "16.67", "17.5", "21"]),
                basicPersonalAmount: 11_932, creditRatePercent: d("8.79")
            ),
            .nunavut: Jurisdiction(
                brackets: slabs([55_801, 111_602, 181_439], ["4", "7", "9", "11.5"]),
                basicPersonalAmount: 19_659, creditRatePercent: 4
            ),
            .ontario: Jurisdiction(
                brackets: slabs([53_891, 107_785, 150_000, 220_000], ["5.05", "9.15", "11.16", "12.16", "13.16"]),
                basicPersonalAmount: 12_989, creditRatePercent: d("5.05"),
                surtaxes: [Surtax(threshold: 5_818, ratePercent: 20), Surtax(threshold: 7_446, ratePercent: 36)]
            ),
            // PEI adds a 20% bracket above $200,000 in 2026.
            .princeEdwardIsland: Jurisdiction(
                brackets: slabs([33_928, 65_820, 106_890, 142_520, 200_000], ["9.5", "13.47", "16.6", "17.62", "19", "20"]),
                basicPersonalAmount: 15_000, creditRatePercent: d("9.5")
            ),
            .quebec: Jurisdiction(
                brackets: slabs([54_345, 108_680, 132_245], ["14", "19", "24", "25.75"]),
                basicPersonalAmount: 18_952, creditRatePercent: 14
            ),
            .saskatchewan: Jurisdiction(
                brackets: slabs([54_532, 155_805], ["10.5", "12.5", "14.5"]),
                basicPersonalAmount: 20_381, creditRatePercent: d("10.5")
            ),
            .yukon: Jurisdiction(
                brackets: slabs([58_523, 117_045, 181_440, 500_000], ["6.4", "9", "10.9", "12.8", "15"]),
                basicPersonalAmount: 16_452, creditRatePercent: d("6.4"),
                bpaReduction: .federal
            ),
        ],

        cpp: PensionPlanRules(
            basicExemption: 3_500,
            maximumPensionableEarnings: 74_600,
            ratePercent: d("5.95"),
            enhancedRatePercent: 1,
            additionalMaximumPensionableEarnings: 85_000,
            additionalRatePercent: 4
        ),
        qpp: PensionPlanRules(
            basicExemption: 3_500,
            maximumPensionableEarnings: 74_600,
            ratePercent: d("6.30"),
            enhancedRatePercent: 1,
            additionalMaximumPensionableEarnings: 85_000,
            additionalRatePercent: 4
        ),
        ei: EIRules(
            maximumInsurableEarnings: 68_900,
            ratePercent: d("1.63"),
            quebecRatePercent: d("1.30")
        ),
        quebecAbatementPercent: d("16.5"),
        capitalGainsInclusionPercent: 50
    )
}
