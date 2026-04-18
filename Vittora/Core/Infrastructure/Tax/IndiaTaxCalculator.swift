import Foundation

/// India income tax calculator with year-aware resident-individual rules.
/// Supports FY 2025-26 with a legacy FY 2024-25 fallback.
struct IndiaTaxCalculator: TaxCalculatorProtocol {
    let country: TaxCountry = .india

    func calculate(profile: TaxProfile) -> TaxEstimate {
        let regime = profile.indiaRegime
        let gross = profile.annualIncome
        let financialYear = Self.supportedFinancialYear(for: profile)

        let standardDeduction = standardDeduction(for: regime, incomeSourceType: profile.incomeSourceType)
        let customDeductionsTotal: Decimal = regime == .oldRegime
            ? profile.customDeductions.reduce(0) { $0 + $1.amount }
            : 0

        let taxableIncome = max(0, gross - standardDeduction - customDeductionsTotal)
        let ageCat = Self.ageCategory(dateOfBirth: profile.dateOfBirth, financialYear: financialYear)
        let slabs = slabs(for: regime, financialYear: financialYear, ageCategory: ageCat)
        let bracketResults = slabs.apply(to: taxableIncome)
        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        let rebate = calculateRebate(
            basicTax: basicTax,
            taxableIncome: taxableIncome,
            regime: regime,
            financialYear: financialYear
        )

        let taxAfterRebate = max(0, basicTax - rebate)
        let surcharge = calculateSurcharge(
            taxAfterRebate: taxAfterRebate,
            grossIncome: gross,
            regime: regime
        )
        let cess = ((taxAfterRebate + surcharge) * 4 / 100).rounded(scale: 2)

        let finalTax = (taxAfterRebate + surcharge + cess).rounded(scale: 2)
        let effectiveRate = gross > 0 ? (finalTax / gross).rounded(scale: 4) : 0
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        return TaxEstimate(
            grossIncome: gross,
            standardDeduction: standardDeduction,
            customDeductionsTotal: customDeductionsTotal,
            taxableIncome: taxableIncome,
            bracketResults: bracketResults,
            basicTax: basicTax,
            rebate: rebate,
            surcharge: surcharge,
            cess: cess,
            finalTax: finalTax,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate,
            country: .india,
            regimeLabel: regime.displayName
        )
    }

    private enum FinancialYear: Int {
        case fy2024 = 2024
        case fy2025 = 2025
    }

    private enum AgeCategory {
        case regular      // under 60
        case senior       // 60–79
        case superSenior  // 80+
    }

    private func standardDeduction(for regime: IndiaRegime, incomeSourceType: IncomeSourceType) -> Decimal {
        guard incomeSourceType == .salaried else { return 0 }
        return regime == .newRegime ? 75_000 : 50_000
    }

    private static func ageCategory(dateOfBirth: Date?, financialYear: FinancialYear) -> AgeCategory {
        guard let dob = dateOfBirth else { return .regular }
        let fyStart = DateComponents(year: financialYear.rawValue, month: 4, day: 1)
        guard let refDate = Calendar.current.date(from: fyStart) else { return .regular }
        let age = Calendar.current.dateComponents([.year], from: dob, to: refDate).year ?? 0
        if age >= 80 { return .superSenior }
        if age >= 60 { return .senior }
        return .regular
    }

    private func slabs(for regime: IndiaRegime, financialYear: FinancialYear, ageCategory: AgeCategory) -> [TaxSlab] {
        switch regime {
        case .newRegime:
            switch financialYear {
            case .fy2024:
                [
                    TaxSlab(lower: 0,         upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
                    TaxSlab(lower: 300_000,   upper: 700_000,   ratePercent: 5,  label: "₹3L – ₹7L"),
                    TaxSlab(lower: 700_000,   upper: 1_000_000, ratePercent: 10, label: "₹7L – ₹10L"),
                    TaxSlab(lower: 1_000_000, upper: 1_200_000, ratePercent: 15, label: "₹10L – ₹12L"),
                    TaxSlab(lower: 1_200_000, upper: 1_500_000, ratePercent: 20, label: "₹12L – ₹15L"),
                    TaxSlab(lower: 1_500_000, upper: nil,       ratePercent: 30, label: "Above ₹15L"),
                ]
            case .fy2025:
                [
                    TaxSlab(lower: 0,         upper: 400_000,   ratePercent: 0,  label: "₹0 – ₹4L"),
                    TaxSlab(lower: 400_000,   upper: 800_000,   ratePercent: 5,  label: "₹4L – ₹8L"),
                    TaxSlab(lower: 800_000,   upper: 1_200_000, ratePercent: 10, label: "₹8L – ₹12L"),
                    TaxSlab(lower: 1_200_000, upper: 1_600_000, ratePercent: 15, label: "₹12L – ₹16L"),
                    TaxSlab(lower: 1_600_000, upper: 2_000_000, ratePercent: 20, label: "₹16L – ₹20L"),
                    TaxSlab(lower: 2_000_000, upper: 2_400_000, ratePercent: 25, label: "₹20L – ₹24L"),
                    TaxSlab(lower: 2_400_000, upper: nil,       ratePercent: 30, label: "Above ₹24L"),
                ]
            }

        case .oldRegime:
            switch ageCategory {
            case .regular:
                [
                    TaxSlab(lower: 0,         upper: 250_000,   ratePercent: 0,  label: "₹0 – ₹2.5L"),
                    TaxSlab(lower: 250_000,   upper: 500_000,   ratePercent: 5,  label: "₹2.5L – ₹5L"),
                    TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                    TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
                ]
            case .senior:
                [
                    TaxSlab(lower: 0,         upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
                    TaxSlab(lower: 300_000,   upper: 500_000,   ratePercent: 5,  label: "₹3L – ₹5L"),
                    TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                    TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
                ]
            case .superSenior:
                [
                    TaxSlab(lower: 0,         upper: 500_000,   ratePercent: 0,  label: "₹0 – ₹5L"),
                    TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
                    TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
                ]
            }
        }
    }

    private func calculateRebate(
        basicTax: Decimal,
        taxableIncome: Decimal,
        regime: IndiaRegime,
        financialYear: FinancialYear
    ) -> Decimal {
        switch regime {
        case .oldRegime:
            guard taxableIncome <= 500_000 else { return 0 }
            return min(basicTax, 12_500)

        case .newRegime:
            let threshold: Decimal
            let cap: Decimal

            switch financialYear {
            case .fy2024:
                threshold = 700_000
                cap = 25_000
            case .fy2025:
                threshold = 1_200_000
                cap = 60_000
            }

            if taxableIncome <= threshold {
                return min(basicTax, cap)
            }

            let excess = taxableIncome - threshold
            return max(0, min(basicTax, cap, basicTax - excess))
        }
    }

    private func calculateSurcharge(
        taxAfterRebate: Decimal,
        grossIncome: Decimal,
        regime: IndiaRegime
    ) -> Decimal {
        let rate: Decimal
        if grossIncome > 5_00_00_000 {
            rate = regime == .newRegime ? 25 : 37
        } else if grossIncome > 2_00_00_000 {
            rate = 25
        } else if grossIncome > 1_00_00_000 {
            rate = 15
        } else if grossIncome > 50_00_000 {
            rate = 10
        } else {
            rate = 0
        }

        return (taxAfterRebate * rate / 100).rounded(scale: 2)
    }

    private static func supportedFinancialYear(for profile: TaxProfile) -> FinancialYear {
        let parsedYear = Int(profile.financialYear.prefix(4)) ?? FinancialYear.fy2025.rawValue
        return parsedYear >= FinancialYear.fy2025.rawValue ? .fy2025 : .fy2024
    }
}
