import Foundation
import VittoraCore

/// In-binary US federal tax rule table keyed by tax year.
/// Adding a future year is a pure data edit here — no calculator logic changes.
enum USTaxRuleTable {
    struct StatusRules: Sendable {
        let standardDeduction: Decimal
        let brackets: [TaxSlab]
        let preferentialZeroRateUpperBound: Decimal
        let preferentialFifteenRateUpperBound: Decimal
        let niitThreshold: Decimal
        let additionalMedicareThreshold: Decimal
    }

    /// Exhaustive per-status lookup; compiler enforces completeness.
    struct ByStatus: Sendable {
        let single: StatusRules
        let marriedFilingJointly: StatusRules
        let marriedFilingSeparately: StatusRules
        let headOfHousehold: StatusRules
        let qualifyingSurvivingSpouse: StatusRules

        nonisolated subscript(status: USFilingStatus) -> StatusRules {
            switch status {
            case .single: single
            case .marriedFilingJointly: marriedFilingJointly
            case .marriedFilingSeparately: marriedFilingSeparately
            case .headOfHousehold: headOfHousehold
            case .qualifyingSurvivingSpouse: qualifyingSurvivingSpouse
            }
        }
    }

    struct YearRules: Sendable {
        let byStatus: ByStatus
        let age65AdditionalStandardDeduction: Decimal
        let socialSecurityWageBase: Decimal
        let socialSecurityRate: Decimal
        let medicareRate: Decimal
        let additionalMedicareRate: Decimal
        let niitRate: Decimal
        let preferentialFifteenRate: Decimal
        let preferentialTwentyRate: Decimal
        let contribution401kBase: Decimal
        let contribution401kCatchUp: Decimal
        let contributionIRABase: Decimal
        let contributionIRACatchUp: Decimal
        let contributionHSAFamily: Decimal
        let contributionHSAIndividual: Decimal
    }

    private struct Entry: Sendable {
        let year: Int
        let rules: YearRules
    }

    /// Ascending by year. Lookup floors to the latest row not after the request.
    nonisolated private static let entries: [Entry] = [
        Entry(year: 2024, rules: year2024),
        Entry(year: 2025, rules: year2025),
        Entry(year: 2026, rules: year2026),
    ]

    nonisolated static var latestTaxYear: Int {
        entries.map(\.year).max() ?? entries[0].year
    }

    /// Resolves to the most recent year in the table that is **not later than**
    /// `taxYear`, clamping up to the earliest year when `taxYear` precedes the
    /// whole table. With the contiguous 2024/2025/2026 keys this reproduces the
    /// former `...2024 → 2024`, `2025 → 2025`, else → 2026` mapping exactly.
    ///
    /// Deliberately a floor and not a nearest-match: rules enacted for a later
    /// year must never be applied to an earlier one, so a table with a gap
    /// (say 2024 and 2030) resolves 2028 to 2024, not 2030.
    nonisolated static func resolvedTaxYear(_ taxYear: Int, in years: [Int]) -> Int {
        years.filter { $0 <= taxYear }.max() ?? years.min() ?? taxYear
    }

    nonisolated static func rules(for taxYear: Int) -> YearRules {
        let resolved = resolvedTaxYear(taxYear, in: entries.map(\.year))
        return entries.first { $0.year == resolved }?.rules ?? entries[0].rules
    }

    // MARK: - 2024

    nonisolated private static let year2024 = YearRules(
        byStatus: {
            let single = StatusRules(
                standardDeduction: 14_600,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                    TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,600 – $47,150"),
                    TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,150 – $100,525"),
                    TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,525 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,950 – $243,725"),
                    TaxSlab(lower: 243_725, upper: 609_350, ratePercent: 35, label: "$243,725 – $609,350"),
                    TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
                ],
                preferentialZeroRateUpperBound: 47_025,
                preferentialFifteenRateUpperBound: 518_900,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            let marriedJoint = StatusRules(
                standardDeduction: 29_200,
                brackets: [
                    TaxSlab(lower: 0,       upper: 23_200,  ratePercent: 10, label: "$0 – $23,200"),
                    TaxSlab(lower: 23_200,  upper: 94_300,  ratePercent: 12, label: "$23,200 – $94,300"),
                    TaxSlab(lower: 94_300,  upper: 201_050, ratePercent: 22, label: "$94,300 – $201,050"),
                    TaxSlab(lower: 201_050, upper: 383_900, ratePercent: 24, label: "$201,050 – $383,900"),
                    TaxSlab(lower: 383_900, upper: 487_450, ratePercent: 32, label: "$383,900 – $487,450"),
                    TaxSlab(lower: 487_450, upper: 731_200, ratePercent: 35, label: "$487,450 – $731,200"),
                    TaxSlab(lower: 731_200, upper: nil,     ratePercent: 37, label: "Over $731,200"),
                ],
                preferentialZeroRateUpperBound: 94_050,
                preferentialFifteenRateUpperBound: 583_750,
                niitThreshold: 250_000,
                additionalMedicareThreshold: 250_000
            )
            let marriedSeparate = StatusRules(
                standardDeduction: 14_600,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                    TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,600 – $47,150"),
                    TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,150 – $100,525"),
                    TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,525 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,950 – $243,725"),
                    TaxSlab(lower: 243_725, upper: 365_600, ratePercent: 35, label: "$243,725 – $365,600"),
                    TaxSlab(lower: 365_600, upper: nil,     ratePercent: 37, label: "Over $365,600"),
                ],
                preferentialZeroRateUpperBound: 47_025,
                preferentialFifteenRateUpperBound: 291_850,
                niitThreshold: 125_000,
                additionalMedicareThreshold: 125_000
            )
            let headOfHousehold = StatusRules(
                standardDeduction: 21_900,
                brackets: [
                    TaxSlab(lower: 0,       upper: 16_550,  ratePercent: 10, label: "$0 – $16,550"),
                    TaxSlab(lower: 16_550,  upper: 63_100,  ratePercent: 12, label: "$16,550 – $63,100"),
                    TaxSlab(lower: 63_100,  upper: 100_500, ratePercent: 22, label: "$63,100 – $100,500"),
                    TaxSlab(lower: 100_500, upper: 191_950, ratePercent: 24, label: "$100,500 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_700, ratePercent: 32, label: "$191,950 – $243,700"),
                    TaxSlab(lower: 243_700, upper: 609_350, ratePercent: 35, label: "$243,700 – $609,350"),
                    TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
                ],
                preferentialZeroRateUpperBound: 63_000,
                preferentialFifteenRateUpperBound: 551_350,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            return ByStatus(
                single: single,
                marriedFilingJointly: marriedJoint,
                marriedFilingSeparately: marriedSeparate,
                headOfHousehold: headOfHousehold,
                qualifyingSurvivingSpouse: marriedJoint
            )
        }(),
        age65AdditionalStandardDeduction: 6_000,
        socialSecurityWageBase: 176_100,
        socialSecurityRate: Decimal(string: "0.062") ?? 0,
        medicareRate: Decimal(string: "0.0145") ?? 0,
        additionalMedicareRate: Decimal(string: "0.009") ?? 0,
        niitRate: Decimal(string: "0.038") ?? 0,
        preferentialFifteenRate: Decimal(string: "0.15") ?? 0,
        preferentialTwentyRate: Decimal(string: "0.20") ?? 0,
        contribution401kBase: 23_500,
        contribution401kCatchUp: 7_500,
        contributionIRABase: 7_000,
        contributionIRACatchUp: 1_000,
        contributionHSAFamily: 8_550,
        contributionHSAIndividual: 4_300
    )

    // MARK: - 2025

    nonisolated private static let year2025 = YearRules(
        byStatus: {
            let single = StatusRules(
                standardDeduction: 15_750,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_925,  ratePercent: 10, label: "$0 – $11,925"),
                    TaxSlab(lower: 11_925,  upper: 48_475,  ratePercent: 12, label: "$11,925 – $48,475"),
                    TaxSlab(lower: 48_475,  upper: 103_350, ratePercent: 22, label: "$48,475 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_525, ratePercent: 32, label: "$197,300 – $250,525"),
                    TaxSlab(lower: 250_525, upper: 626_350, ratePercent: 35, label: "$250,525 – $626,350"),
                    TaxSlab(lower: 626_350, upper: nil,     ratePercent: 37, label: "Over $626,350"),
                ],
                preferentialZeroRateUpperBound: 48_350,
                preferentialFifteenRateUpperBound: 533_400,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            let marriedJoint = StatusRules(
                standardDeduction: 31_500,
                brackets: [
                    TaxSlab(lower: 0,       upper: 23_850,  ratePercent: 10, label: "$0 – $23,850"),
                    TaxSlab(lower: 23_850,  upper: 96_950,  ratePercent: 12, label: "$23,850 – $96,950"),
                    TaxSlab(lower: 96_950,  upper: 206_700, ratePercent: 22, label: "$96,950 – $206,700"),
                    TaxSlab(lower: 206_700, upper: 394_600, ratePercent: 24, label: "$206,700 – $394,600"),
                    TaxSlab(lower: 394_600, upper: 501_050, ratePercent: 32, label: "$394,600 – $501,050"),
                    TaxSlab(lower: 501_050, upper: 751_600, ratePercent: 35, label: "$501,050 – $751,600"),
                    TaxSlab(lower: 751_600, upper: nil,     ratePercent: 37, label: "Over $751,600"),
                ],
                preferentialZeroRateUpperBound: 96_700,
                preferentialFifteenRateUpperBound: 600_050,
                niitThreshold: 250_000,
                additionalMedicareThreshold: 250_000
            )
            let marriedSeparate = StatusRules(
                standardDeduction: 15_750,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_925,  ratePercent: 10, label: "$0 – $11,925"),
                    TaxSlab(lower: 11_925,  upper: 48_475,  ratePercent: 12, label: "$11,925 – $48,475"),
                    TaxSlab(lower: 48_475,  upper: 103_350, ratePercent: 22, label: "$48,475 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_525, ratePercent: 32, label: "$197,300 – $250,525"),
                    TaxSlab(lower: 250_525, upper: 375_800, ratePercent: 35, label: "$250,525 – $375,800"),
                    TaxSlab(lower: 375_800, upper: nil,     ratePercent: 37, label: "Over $375,800"),
                ],
                preferentialZeroRateUpperBound: 48_350,
                preferentialFifteenRateUpperBound: 300_000,
                niitThreshold: 125_000,
                additionalMedicareThreshold: 125_000
            )
            let headOfHousehold = StatusRules(
                standardDeduction: 23_625,
                brackets: [
                    TaxSlab(lower: 0,       upper: 17_000,  ratePercent: 10, label: "$0 – $17,000"),
                    TaxSlab(lower: 17_000,  upper: 64_850,  ratePercent: 12, label: "$17,000 – $64,850"),
                    TaxSlab(lower: 64_850,  upper: 103_350, ratePercent: 22, label: "$64,850 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_500, ratePercent: 32, label: "$197,300 – $250,500"),
                    TaxSlab(lower: 250_500, upper: 626_350, ratePercent: 35, label: "$250,500 – $626,350"),
                    TaxSlab(lower: 626_350, upper: nil,     ratePercent: 37, label: "Over $626,350"),
                ],
                preferentialZeroRateUpperBound: 64_750,
                preferentialFifteenRateUpperBound: 566_700,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            return ByStatus(
                single: single,
                marriedFilingJointly: marriedJoint,
                marriedFilingSeparately: marriedSeparate,
                headOfHousehold: headOfHousehold,
                qualifyingSurvivingSpouse: marriedJoint
            )
        }(),
        age65AdditionalStandardDeduction: 6_000,
        socialSecurityWageBase: 176_100,
        socialSecurityRate: Decimal(string: "0.062") ?? 0,
        medicareRate: Decimal(string: "0.0145") ?? 0,
        additionalMedicareRate: Decimal(string: "0.009") ?? 0,
        niitRate: Decimal(string: "0.038") ?? 0,
        preferentialFifteenRate: Decimal(string: "0.15") ?? 0,
        preferentialTwentyRate: Decimal(string: "0.20") ?? 0,
        contribution401kBase: 23_500,
        contribution401kCatchUp: 7_500,
        contributionIRABase: 7_000,
        contributionIRACatchUp: 1_000,
        contributionHSAFamily: 8_550,
        contributionHSAIndividual: 4_300
    )

    // MARK: - 2026

    nonisolated private static let year2026 = YearRules(
        byStatus: {
            let single = StatusRules(
                standardDeduction: 16_100,
                brackets: [
                    TaxSlab(lower: 0,       upper: 12_400,  ratePercent: 10, label: "$0 – $12,400"),
                    TaxSlab(lower: 12_400,  upper: 50_400,  ratePercent: 12, label: "$12,400 – $50,400"),
                    TaxSlab(lower: 50_400,  upper: 105_700, ratePercent: 22, label: "$50,400 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_775, ratePercent: 24, label: "$105,700 – $201,775"),
                    TaxSlab(lower: 201_775, upper: 256_225, ratePercent: 32, label: "$201,775 – $256,225"),
                    TaxSlab(lower: 256_225, upper: 640_600, ratePercent: 35, label: "$256,225 – $640,600"),
                    TaxSlab(lower: 640_600, upper: nil,     ratePercent: 37, label: "Over $640,600"),
                ],
                preferentialZeroRateUpperBound: 50_000,
                preferentialFifteenRateUpperBound: 545_000,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            let marriedJoint = StatusRules(
                standardDeduction: 32_200,
                brackets: [
                    TaxSlab(lower: 0,       upper: 24_800,  ratePercent: 10, label: "$0 – $24,800"),
                    TaxSlab(lower: 24_800,  upper: 100_800, ratePercent: 12, label: "$24,800 – $100,800"),
                    TaxSlab(lower: 100_800, upper: 211_400, ratePercent: 22, label: "$100,800 – $211,400"),
                    TaxSlab(lower: 211_400, upper: 403_550, ratePercent: 24, label: "$211,400 – $403,550"),
                    TaxSlab(lower: 403_550, upper: 512_450, ratePercent: 32, label: "$403,550 – $512,450"),
                    TaxSlab(lower: 512_450, upper: 768_700, ratePercent: 35, label: "$512,450 – $768,700"),
                    TaxSlab(lower: 768_700, upper: nil,     ratePercent: 37, label: "Over $768,700"),
                ],
                preferentialZeroRateUpperBound: 100_000,
                preferentialFifteenRateUpperBound: 612_000,
                niitThreshold: 250_000,
                additionalMedicareThreshold: 250_000
            )
            let marriedSeparate = StatusRules(
                standardDeduction: 16_100,
                brackets: [
                    TaxSlab(lower: 0,       upper: 12_400,  ratePercent: 10, label: "$0 – $12,400"),
                    TaxSlab(lower: 12_400,  upper: 50_400,  ratePercent: 12, label: "$12,400 – $50,400"),
                    TaxSlab(lower: 50_400,  upper: 105_700, ratePercent: 22, label: "$50,400 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_775, ratePercent: 24, label: "$105,700 – $201,775"),
                    TaxSlab(lower: 201_775, upper: 256_225, ratePercent: 32, label: "$201,775 – $256,225"),
                    TaxSlab(lower: 256_225, upper: 384_350, ratePercent: 35, label: "$256,225 – $384,350"),
                    TaxSlab(lower: 384_350, upper: nil,     ratePercent: 37, label: "Over $384,350"),
                ],
                preferentialZeroRateUpperBound: 50_000,
                preferentialFifteenRateUpperBound: 306_000,
                niitThreshold: 125_000,
                additionalMedicareThreshold: 125_000
            )
            let headOfHousehold = StatusRules(
                standardDeduction: 24_150,
                brackets: [
                    TaxSlab(lower: 0,       upper: 17_700,  ratePercent: 10, label: "$0 – $17,700"),
                    TaxSlab(lower: 17_700,  upper: 67_450,  ratePercent: 12, label: "$17,700 – $67,450"),
                    TaxSlab(lower: 67_450,  upper: 105_700, ratePercent: 22, label: "$67,450 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_750, ratePercent: 24, label: "$105,700 – $201,750"),
                    TaxSlab(lower: 201_750, upper: 256_200, ratePercent: 32, label: "$201,750 – $256,200"),
                    TaxSlab(lower: 256_200, upper: 640_600, ratePercent: 35, label: "$256,200 – $640,600"),
                    TaxSlab(lower: 640_600, upper: nil,     ratePercent: 37, label: "Over $640,600"),
                ],
                preferentialZeroRateUpperBound: 67_000,
                preferentialFifteenRateUpperBound: 578_000,
                niitThreshold: 200_000,
                additionalMedicareThreshold: 200_000
            )
            return ByStatus(
                single: single,
                marriedFilingJointly: marriedJoint,
                marriedFilingSeparately: marriedSeparate,
                headOfHousehold: headOfHousehold,
                qualifyingSurvivingSpouse: marriedJoint
            )
        }(),
        age65AdditionalStandardDeduction: 6_000,
        socialSecurityWageBase: 184_500,
        socialSecurityRate: Decimal(string: "0.062") ?? 0,
        medicareRate: Decimal(string: "0.0145") ?? 0,
        additionalMedicareRate: Decimal(string: "0.009") ?? 0,
        niitRate: Decimal(string: "0.038") ?? 0,
        preferentialFifteenRate: Decimal(string: "0.15") ?? 0,
        preferentialTwentyRate: Decimal(string: "0.20") ?? 0,
        contribution401kBase: 24_500,
        contribution401kCatchUp: 8_000,
        contributionIRABase: 7_500,
        contributionIRACatchUp: 1_000,
        contributionHSAFamily: 8_750,
        contributionHSAIndividual: 4_400
    )
}
