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
        let age = ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear)

        let limit401k = statutory401kLimit(taxYear: taxYear, age: age)
        let limitIRA = statutoryIRALimit(taxYear: taxYear, age50Plus: (age ?? 0) >= 50)
        let limitHSA = statutoryHSALimit(taxYear: taxYear, familyCoverage: advanced.usHSAFamilyCoverage, age: age)

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

    /// Age-aware 401(k) limit: the 50+ catch-up, or the larger SECURE 2.0
    /// catch-up for ages 60–63 (2025 on).
    nonisolated static func statutory401kLimit(taxYear: Int, age: Int?) -> Decimal {
        let rules = USTaxRuleTable.rules(for: taxYear)
        guard let age, age >= 50 else { return rules.contribution401kBase }
        let catchUp = (60...63).contains(age) ? rules.contribution401kCatchUpAge60To63 : rules.contribution401kCatchUp
        return rules.contribution401kBase + catchUp
    }

    /// HSA limit with the statutory $1,000 catch-up from age 55.
    nonisolated static func statutoryHSALimit(taxYear: Int, familyCoverage: Bool, age: Int?) -> Decimal {
        let base = statutoryHSALimit(taxYear: taxYear, familyCoverage: familyCoverage)
        guard let age, age >= 55 else { return base }
        return base + USTaxRuleTable.rules(for: taxYear).contributionHSACatchUp
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

    /// Age at the end of the tax year, by the IRS convention that you attain an
    /// age on the day BEFORE the birthday — so a 1 January birthday counts for
    /// the year before. Calendar dates are compared, not instants.
    nonisolated static func ageAtEndOfTaxYear(dateOfBirth: Date?, taxYear: Int) -> Int? {
        guard let dateOfBirth else { return nil }
        let birth = Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth)
        guard let year = birth.year, let month = birth.month, let day = birth.day else { return nil }
        let birthdayOnJanuaryFirst = month == 1 && day == 1
        return taxYear - year + (birthdayOnJanuaryFirst ? 1 : 0)
    }
}
