import Foundation
import VittoraCore

struct USContributionUtilization: Sendable, Identifiable, Equatable {
    nonisolated let id: String
    nonisolated let title: String
    nonisolated let contributed: Decimal
    nonisolated let statutoryLimit: Decimal

    nonisolated var headroom: Decimal { max(0, statutoryLimit - contributed) }

    nonisolated var utilizationFraction: Double {
        guard statutoryLimit > 0 else { return 0 }
        let used = min(contributed, statutoryLimit)
        return min(1, (used as NSDecimalNumber).doubleValue / (statutoryLimit as NSDecimalNumber).doubleValue)
    }
}

enum USContributionHeadroomEngine {
    nonisolated static func utilizations(profile: TaxProfile, taxYear: Int) -> [USContributionUtilization] {
        let advanced = profile.advancedInputs
        let age50Plus = ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear).map { $0 >= 50 } ?? false

        let limit401k = statutory401kLimit(taxYear: taxYear, age50Plus: age50Plus)
        let limitIRA = statutoryIRALimit(taxYear: taxYear, age50Plus: age50Plus)
        let limitHSA = statutoryHSALimit(taxYear: taxYear, familyCoverage: advanced.usHSAFamilyCoverage)

        return [
            USContributionUtilization(
                id: "401k",
                title: String(localized: "401(k)"),
                contributed: advanced.us401kYTDContributed,
                statutoryLimit: limit401k
            ),
            USContributionUtilization(
                id: "ira",
                title: String(localized: "IRA"),
                contributed: advanced.usIRAYTDContributed,
                statutoryLimit: limitIRA
            ),
            USContributionUtilization(
                id: "hsa",
                title: advanced.usHSAFamilyCoverage
                    ? String(localized: "HSA (family)")
                    : String(localized: "HSA (individual)"),
                contributed: advanced.usHSAYTDContributed,
                statutoryLimit: limitHSA
            ),
        ]
    }

    nonisolated static func supplementaryHeadroomLines(
        profile: TaxProfile,
        taxYear: Int
    ) -> [TaxSupplementaryLine] {
        utilizations(profile: profile, taxYear: taxYear).map { item in
            TaxSupplementaryLine(
                title: String(localized: "\(item.title) headroom remaining"),
                amount: item.headroom
            )
        }
    }

    nonisolated static func statutory401kLimit(taxYear: Int, age50Plus: Bool) -> Decimal {
        let rules = USTaxRuleTable.rules(for: taxYear)
        return age50Plus
            ? rules.contribution401kBase + rules.contribution401kCatchUp
            : rules.contribution401kBase
    }

    nonisolated static func statutoryIRALimit(taxYear: Int, age50Plus: Bool) -> Decimal {
        let rules = USTaxRuleTable.rules(for: taxYear)
        return age50Plus
            ? rules.contributionIRABase + rules.contributionIRACatchUp
            : rules.contributionIRABase
    }

    nonisolated static func statutoryHSALimit(taxYear: Int, familyCoverage: Bool) -> Decimal {
        let rules = USTaxRuleTable.rules(for: taxYear)
        return familyCoverage ? rules.contributionHSAFamily : rules.contributionHSAIndividual
    }

    nonisolated private static func ageAtEndOfTaxYear(dateOfBirth: Date?, taxYear: Int) -> Int? {
        guard let dob = dateOfBirth else { return nil }
        guard let end = Calendar.current.date(from: DateComponents(year: taxYear, month: 12, day: 31)) else {
            return nil
        }
        return Calendar.current.dateComponents([.year], from: dob, to: end).year
    }
}
