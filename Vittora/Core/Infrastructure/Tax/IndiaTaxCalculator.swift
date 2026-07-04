import Foundation
import VittoraCore

/// India income tax calculator with year-aware resident-individual rules.
/// Supports FY 2025-26 with a legacy FY 2024-25 fallback.
struct IndiaTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .india

    nonisolated private static let stcgRate = Decimal(sign: .plus, exponent: -1, significand: 2)
    nonisolated private static let ltcgRate = Decimal(sign: .plus, exponent: -3, significand: 125)
    nonisolated private static let ltcgExemption: Decimal = 125_000
    nonisolated private static let cessRate = Decimal(sign: .plus, exponent: -2, significand: 4)
    nonisolated private static let maxSpecialSurchargeRate = Decimal(15)
    nonisolated private static let surchargeThresholds: [Decimal] = [
        50_00_000,
        1_00_00_000,
        2_00_00_000,
        5_00_00_000,
    ]

    private struct TaxComputationInput: Sendable {
        let gross: Decimal
        let advancedInputs: TaxAdvancedInputs
        let regime: IndiaRegime
        let financialYear: FinancialYear
        let incomeSourceType: IncomeSourceType
        let dateOfBirth: Date?
        let customDeductions: [TaxDeduction]
        let financialYearLabel: String
    }

    private struct TaxCoreAmounts: Sendable {
        nonisolated let standardDeduction: Decimal
        nonisolated let customDeductionsTotal: Decimal
        nonisolated let taxableIncome: Decimal
        nonisolated let bracketResults: [TaxBracketResult]
        nonisolated let basicTax: Decimal
        nonisolated let rebate: Decimal
        nonisolated let ltcgTax: Decimal
        nonisolated let stcgTax: Decimal

        nonisolated var ordinaryTax: Decimal { max(0, basicTax - rebate) }
        nonisolated var specialRateTax: Decimal { ltcgTax + stcgTax }
        nonisolated var taxAfterRebate: Decimal { ordinaryTax + specialRateTax }
        nonisolated var marginalRate: Decimal { bracketResults.last?.ratePercent ?? 0 }
    }

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        let input = Self.input(from: profile)
        let core = computeCoreAmounts(input: input)
        let totalGrossForSurcharge = input.gross + input.advancedInputs.indiaEquityLTCG + input.advancedInputs.indiaEquitySTCG

        let surcharge = calculateSurcharge(
            core: core,
            grossIncome: totalGrossForSurcharge,
            regime: input.regime,
            profile: profile
        )
        let cess = ((core.taxAfterRebate + surcharge) * Self.cessRate).rounded(scale: 2)

        let finalTax = (core.taxAfterRebate + surcharge + cess).rounded(scale: 2)
        let denom = totalGrossForSurcharge
        let effectiveRate = denom > 0 ? (finalTax / denom).rounded(scale: 4) : 0
        let financialYear = input.financialYear
        let ruleSetID = "IN_FY\(financialYear == .fy2025 ? "2025_26" : "2024_25")"

        var supplementary: [TaxSupplementaryLine] = []
        if core.ltcgTax > 0 {
            supplementary.append(TaxSupplementaryLine(title: String(localized: "Equity LTCG (Section 112A-style)"), amount: core.ltcgTax))
        }
        if core.stcgTax > 0 {
            supplementary.append(TaxSupplementaryLine(title: String(localized: "Equity STCG (simplified)"), amount: core.stcgTax))
        }

        let assumptions: [String] = [
            String(localized: "Ordinary income is slab-taxed; equity LTCG/STCG use simplified rates and exemptions.")
        ]
        var warnings: [String] = []
        if input.advancedInputs.indiaEquityLTCG > 0 || input.advancedInputs.indiaEquitySTCG > 0 {
            warnings.append(String(localized: "Section 87A rebate applies to ordinary slab tax only, not to special-rate equity gains."))
            if totalGrossForSurcharge > 1_00_00_000 {
                warnings.append(String(localized: "Surcharge on equity LTCG/STCG is capped at 15% under Sections 111A/112A-style modeling."))
            }
        }
        if input.regime == .oldRegime {
            let deductionResolution = IndiaSectionDeductionEngine.resolve(
                deductions: input.customDeductions,
                advancedInputs: input.advancedInputs,
                dateOfBirth: input.dateOfBirth,
                financialYearLabel: input.financialYearLabel
            )
            warnings.append(contentsOf: deductionResolution.warnings)
        }

        let exclusions: [String] = [
            String(localized: "State taxes and cess on surcharges are modeled only at the federal level; verify with a CA.")
        ]

        return TaxEstimate(
            grossIncome: input.gross,
            standardDeduction: core.standardDeduction,
            customDeductionsTotal: core.customDeductionsTotal,
            taxableIncome: core.taxableIncome,
            bracketResults: core.bracketResults,
            basicTax: core.basicTax,
            rebate: core.rebate,
            surcharge: surcharge,
            cess: cess,
            finalTax: finalTax,
            effectiveRate: effectiveRate,
            marginalRate: core.marginalRate,
            country: .india,
            regimeLabel: input.regime.displayName,
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.in.v1",
            ruleSetID: ruleSetID,
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }

    nonisolated private static let rulesLastUpdated: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 18)) ?? .now
    }()

    nonisolated private static func input(from profile: TaxProfile) -> TaxComputationInput {
        TaxComputationInput(
            gross: profile.annualIncome,
            advancedInputs: profile.advancedInputs,
            regime: profile.indiaRegime,
            financialYear: supportedFinancialYear(for: profile),
            incomeSourceType: profile.incomeSourceType,
            dateOfBirth: profile.dateOfBirth,
            customDeductions: profile.customDeductions,
            financialYearLabel: profile.financialYear
        )
    }

    nonisolated private func computeCoreAmounts(input: TaxComputationInput) -> TaxCoreAmounts {
        let standardDeduction = standardDeduction(
            for: input.regime,
            incomeSourceType: input.incomeSourceType,
            financialYear: input.financialYear
        )
        let deductionResolution = IndiaSectionDeductionEngine.resolve(
            deductions: input.customDeductions,
            advancedInputs: input.advancedInputs,
            dateOfBirth: input.dateOfBirth,
            financialYearLabel: input.financialYearLabel
        )
        let customDeductionsTotal: Decimal = input.regime == .oldRegime
            ? deductionResolution.allowedTotal
            : 0

        let taxableIncome = max(0, input.gross - standardDeduction - customDeductionsTotal)
        let ageCat = Self.ageCategory(dateOfBirth: input.dateOfBirth, financialYear: input.financialYear)
        let bracketResults = slabs(for: input.regime, financialYear: input.financialYear, ageCategory: ageCat)
            .apply(to: taxableIncome)
        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        let rebate = calculateRebate(
            basicTax: basicTax,
            taxableIncome: taxableIncome,
            regime: input.regime,
            financialYear: input.financialYear
        )

        let ltcgTax = Self.equityLongTermCapitalGainsTax(amount: input.advancedInputs.indiaEquityLTCG)
        let stcgTax = (input.advancedInputs.indiaEquitySTCG * Self.stcgRate).rounded(scale: 2)

        return TaxCoreAmounts(
            standardDeduction: standardDeduction,
            customDeductionsTotal: customDeductionsTotal,
            taxableIncome: taxableIncome,
            bracketResults: bracketResults,
            basicTax: basicTax,
            rebate: rebate,
            ltcgTax: ltcgTax,
            stcgTax: stcgTax
        )
    }

    /// Simplified: 12.5% on amount above ₹1.25L exemption (new regime equity LTCG).
    nonisolated private static func equityLongTermCapitalGainsTax(amount: Decimal) -> Decimal {
        guard amount > 0 else { return 0 }
        let taxable = max(0, amount - ltcgExemption)
        return (taxable * ltcgRate).rounded(scale: 2)
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

    nonisolated private func standardDeduction(
        for regime: IndiaRegime,
        incomeSourceType: IncomeSourceType,
        financialYear: FinancialYear
    ) -> Decimal {
        guard incomeSourceType == .salaried else { return 0 }
        switch regime {
        case .newRegime:
            return financialYear == .fy2024 || financialYear == .fy2025 ? 75_000 : 50_000
        case .oldRegime:
            return 50_000
        }
    }

    nonisolated private static func ageCategory(dateOfBirth: Date?, financialYear: FinancialYear) -> AgeCategory {
        guard let dob = dateOfBirth else { return .regular }
        let fyStart = DateComponents(year: financialYear.rawValue, month: 4, day: 1)
        guard let refDate = Calendar.current.date(from: fyStart) else { return .regular }
        let age = Calendar.current.dateComponents([.year], from: dob, to: refDate).year ?? 0
        if age >= 80 { return .superSenior }
        if age >= 60 { return .senior }
        return .regular
    }

    nonisolated private func slabs(for regime: IndiaRegime, financialYear: FinancialYear, ageCategory: AgeCategory) -> [TaxSlab] {
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

    nonisolated private func calculateRebate(
        basicTax: Decimal,
        taxableIncome: Decimal,
        regime: IndiaRegime,
        financialYear: FinancialYear
    ) -> Decimal {
        switch regime {
        case .oldRegime:
            let threshold: Decimal = 500_000
            let cap: Decimal = 12_500
            if taxableIncome <= threshold {
                return min(basicTax, cap)
            }
            let excess = taxableIncome - threshold
            return max(0, min(basicTax, cap, basicTax - excess))

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

    nonisolated private func nominalSurchargeRate(grossIncome: Decimal, regime: IndiaRegime) -> Decimal {
        if grossIncome > 5_00_00_000 {
            return regime == .newRegime ? 25 : 37
        }
        if grossIncome > 2_00_00_000 { return 25 }
        if grossIncome > 1_00_00_000 { return 15 }
        if grossIncome > 50_00_000 { return 10 }
        return 0
    }

    nonisolated private func rawSurcharge(core: TaxCoreAmounts, grossIncome: Decimal, regime: IndiaRegime) -> Decimal {
        let rate = nominalSurchargeRate(grossIncome: grossIncome, regime: regime)
        guard rate > 0 else { return 0 }

        let specialRate = min(rate, Self.maxSpecialSurchargeRate)
        let ordinaryPart = (core.ordinaryTax * rate / 100).rounded(scale: 2)
        let specialPart = (core.specialRateTax * specialRate / 100).rounded(scale: 2)
        return ordinaryPart + specialPart
    }

    nonisolated private func calculateSurcharge(
        core: TaxCoreAmounts,
        grossIncome: Decimal,
        regime: IndiaRegime,
        profile: TaxProfile
    ) -> Decimal {
        let preliminary = rawSurcharge(core: core, grossIncome: grossIncome, regime: regime)
        return applySurchargeMarginalRelief(
            core: core,
            grossIncome: grossIncome,
            preliminarySurcharge: preliminary,
            profile: profile
        )
    }

    /// Caps incremental (income tax + surcharge) **before cess** at gross income above the
    /// crossed surcharge threshold — statutory ordering; cess is applied afterward (A13).
    nonisolated private func applySurchargeMarginalRelief(
        core: TaxCoreAmounts,
        grossIncome: Decimal,
        preliminarySurcharge: Decimal,
        profile: TaxProfile
    ) -> Decimal {
        guard let threshold = Self.surchargeThresholds.last(where: { grossIncome > $0 }) else {
            return preliminarySurcharge
        }

        let excess = grossIncome - threshold
        let preCessAtThreshold = preCessTotal(
            forGrossIncome: threshold,
            profile: profile,
            applySurchargeMarginalRelief: false
        )
        let cappedPreCess = preCessAtThreshold + excess

        let actualPreCess = core.taxAfterRebate + preliminarySurcharge
        guard actualPreCess > cappedPreCess else { return preliminarySurcharge }

        return max(0, cappedPreCess - core.taxAfterRebate).rounded(scale: 2)
    }

    nonisolated private func preCessTotal(
        forGrossIncome gross: Decimal,
        profile: TaxProfile,
        applySurchargeMarginalRelief: Bool
    ) -> Decimal {
        var adjusted = profile
        adjusted.annualIncome = gross
        let input = Self.input(from: adjusted)
        let core = computeCoreAmounts(input: input)
        let totalGross = gross + input.advancedInputs.indiaEquityLTCG + input.advancedInputs.indiaEquitySTCG
        let surcharge: Decimal
        if applySurchargeMarginalRelief {
            surcharge = calculateSurcharge(core: core, grossIncome: totalGross, regime: input.regime, profile: adjusted)
        } else {
            surcharge = rawSurcharge(core: core, grossIncome: totalGross, regime: input.regime)
        }
        return core.taxAfterRebate + surcharge
    }

    nonisolated private static func supportedFinancialYear(for profile: TaxProfile) -> FinancialYear {
        let parsedYear = Int(profile.financialYear.prefix(4)) ?? FinancialYear.fy2025.rawValue
        return parsedYear >= FinancialYear.fy2025.rawValue ? .fy2025 : .fy2024
    }
}
