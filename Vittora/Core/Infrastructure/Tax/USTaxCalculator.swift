import Foundation

/// US federal income tax calculator for tax year 2024.
/// Supports all four filing statuses with standard deduction.
struct USTaxCalculator: TaxCalculatorProtocol {
    let country: TaxCountry = .unitedStates

    func calculate(profile: TaxProfile) -> TaxEstimate {
        let status = profile.filingStatus
        let gross = profile.annualIncome

        let standardDeduction = Self.standardDeduction(for: status)

        // Custom deductions (itemized — user may enter mortgage interest, SALT, etc.)
        let customDeductionsTotal = profile.customDeductions.reduce(Decimal(0)) { $0 + $1.amount }

        // Take greater of standard or itemized
        let totalDeduction = max(standardDeduction, customDeductionsTotal)
        let taxableIncome = max(0, gross - totalDeduction)

        let slabs = Self.brackets(for: status)
        let bracketResults = slabs.apply(to: taxableIncome)

        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }
        let finalTax = basicTax.rounded(scale: 2)
        let effectiveRate = gross > 0 ? (finalTax / gross).rounded(scale: 4) : 0
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        return TaxEstimate(
            grossIncome: gross,
            standardDeduction: totalDeduction,
            customDeductionsTotal: customDeductionsTotal > standardDeduction ? customDeductionsTotal : 0,
            taxableIncome: taxableIncome,
            bracketResults: bracketResults,
            basicTax: basicTax,
            rebate: 0,
            surcharge: 0,
            cess: 0,
            finalTax: finalTax,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate,
            country: .unitedStates,
            regimeLabel: status.displayName
        )
    }

    // MARK: - Standard Deductions (2024)

    static func standardDeduction(for status: USFilingStatus) -> Decimal {
        switch status {
        case .single:                  return 14_600
        case .marriedFilingJointly:    return 29_200
        case .marriedFilingSeparately: return 14_600
        case .headOfHousehold:         return 21_900
        }
    }

    // MARK: - Tax Brackets (2024)

    static func brackets(for status: USFilingStatus) -> [TaxSlab] {
        switch status {
        case .single:
            return [
                TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,601 – $47,150"),
                TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,151 – $100,525"),
                TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,526 – $191,950"),
                TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,951 – $243,725"),
                TaxSlab(lower: 243_725, upper: 609_350, ratePercent: 35, label: "$243,726 – $609,350"),
                TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
            ]
        case .marriedFilingJointly:
            return [
                TaxSlab(lower: 0,       upper: 23_200,  ratePercent: 10, label: "$0 – $23,200"),
                TaxSlab(lower: 23_200,  upper: 94_300,  ratePercent: 12, label: "$23,201 – $94,300"),
                TaxSlab(lower: 94_300,  upper: 201_050, ratePercent: 22, label: "$94,301 – $201,050"),
                TaxSlab(lower: 201_050, upper: 383_900, ratePercent: 24, label: "$201,051 – $383,900"),
                TaxSlab(lower: 383_900, upper: 487_450, ratePercent: 32, label: "$383,901 – $487,450"),
                TaxSlab(lower: 487_450, upper: 731_200, ratePercent: 35, label: "$487,451 – $731,200"),
                TaxSlab(lower: 731_200, upper: nil,     ratePercent: 37, label: "Over $731,200"),
            ]
        case .marriedFilingSeparately:
            return [
                TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,601 – $47,150"),
                TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,151 – $100,525"),
                TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,526 – $191,950"),
                TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,951 – $243,725"),
                TaxSlab(lower: 243_725, upper: 365_600, ratePercent: 35, label: "$243,726 – $365,600"),
                TaxSlab(lower: 365_600, upper: nil,     ratePercent: 37, label: "Over $365,600"),
            ]
        case .headOfHousehold:
            return [
                TaxSlab(lower: 0,       upper: 16_550,  ratePercent: 10, label: "$0 – $16,550"),
                TaxSlab(lower: 16_550,  upper: 63_100,  ratePercent: 12, label: "$16,551 – $63,100"),
                TaxSlab(lower: 63_100,  upper: 100_500, ratePercent: 22, label: "$63,101 – $100,500"),
                TaxSlab(lower: 100_500, upper: 191_950, ratePercent: 24, label: "$100,501 – $191,950"),
                TaxSlab(lower: 191_950, upper: 243_700, ratePercent: 32, label: "$191,951 – $243,700"),
                TaxSlab(lower: 243_700, upper: 609_350, ratePercent: 35, label: "$243,701 – $609,350"),
                TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
            ]
        }
    }
}
