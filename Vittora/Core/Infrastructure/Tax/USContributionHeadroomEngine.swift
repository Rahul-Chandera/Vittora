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
        let base: Decimal = taxYear >= 2026 ? 24_500 : 23_500
        let catchUp: Decimal = taxYear >= 2026 ? 8_000 : 7_500
        return age50Plus ? base + catchUp : base
    }

    nonisolated static func statutoryIRALimit(taxYear: Int, age50Plus: Bool) -> Decimal {
        let base: Decimal = taxYear >= 2026 ? 7_500 : 7_000
        let catchUp: Decimal = 1_000
        return age50Plus ? base + catchUp : base
    }

    nonisolated static func statutoryHSALimit(taxYear: Int, familyCoverage: Bool) -> Decimal {
        if familyCoverage {
            return taxYear >= 2026 ? 8_750 : 8_550
        }
        return taxYear >= 2026 ? 4_400 : 4_300
    }

    nonisolated private static func ageAtEndOfTaxYear(dateOfBirth: Date?, taxYear: Int) -> Int? {
        guard let dob = dateOfBirth else { return nil }
        guard let end = Calendar.current.date(from: DateComponents(year: taxYear, month: 12, day: 31)) else {
            return nil
        }
        return Calendar.current.dateComponents([.year], from: dob, to: end).year
    }
}
