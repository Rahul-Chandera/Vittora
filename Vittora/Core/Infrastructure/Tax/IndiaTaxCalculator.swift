import Foundation
import VittoraCore

/// India income tax calculator with year-aware resident-individual rules.
/// Supports FY 2025-26 with a legacy FY 2024-25 fallback.
struct IndiaTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .india

    private struct TaxComputationInput: Sendable {
        let gross: Decimal
        let advancedInputs: TaxAdvancedInputs
        let regime: IndiaRegime
        let financialYear: Int
        let yearRules: IndiaTaxRuleTable.YearRules
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
            yearRules: input.yearRules,
            profile: profile
        )
        let cess = ((core.taxAfterRebate + surcharge) * input.yearRules.cessRate).rounded(scale: 2)

        let finalTax = (core.taxAfterRebate + surcharge + cess).rounded(scale: 2)
        let denom = totalGrossForSurcharge
        let effectiveRate = denom > 0 ? (finalTax / denom).rounded(scale: 4) : 0
        let ruleSetID = input.yearRules.ruleSetID

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
            if totalGrossForSurcharge > input.yearRules.surcharge.specialRateCapWarningThreshold {
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
        let financialYear = supportedFinancialYear(for: profile)
        return TaxComputationInput(
            gross: profile.annualIncome,
            advancedInputs: profile.advancedInputs,
            regime: profile.indiaRegime,
            financialYear: financialYear,
            yearRules: IndiaTaxRuleTable.rules(for: financialYear),
            incomeSourceType: profile.incomeSourceType,
            dateOfBirth: profile.dateOfBirth,
            customDeductions: profile.customDeductions,
            financialYearLabel: profile.financialYear
        )
    }

    nonisolated private func computeCoreAmounts(input: TaxComputationInput) -> TaxCoreAmounts {
        let rules = input.yearRules
        let standardDeduction = standardDeduction(
            for: input.regime,
            incomeSourceType: input.incomeSourceType,
            rules: rules
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
        let bracketResults = slabs(for: input.regime, ageCategory: ageCat, rules: rules)
            .apply(to: taxableIncome)
        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        let rebate = calculateRebate(
            basicTax: basicTax,
            taxableIncome: taxableIncome,
            regime: input.regime,
            rules: rules
        )

        let ltcgTax = Self.equityLongTermCapitalGainsTax(amount: input.advancedInputs.indiaEquityLTCG, rules: rules)
        let stcgTax = (input.advancedInputs.indiaEquitySTCG * rules.equitySTCGRate).rounded(scale: 2)

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
    nonisolated private static func equityLongTermCapitalGainsTax(
        amount: Decimal,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        guard amount > 0 else { return 0 }
        let taxable = max(0, amount - rules.equityLTCGExemption)
        return (taxable * rules.equityLTCGRate).rounded(scale: 2)
    }

    private enum AgeCategory {
        case regular      // under 60
        case senior       // 60–79
        case superSenior  // 80+
    }

    nonisolated private func standardDeduction(
        for regime: IndiaRegime,
        incomeSourceType: IncomeSourceType,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        guard incomeSourceType == .salaried else { return 0 }
        switch regime {
        case .newRegime:
            return rules.newRegimeSalariedStandardDeduction
        case .oldRegime:
            return rules.oldRegimeSalariedStandardDeduction
        }
    }

    nonisolated private static func ageCategory(dateOfBirth: Date?, financialYear: Int) -> AgeCategory {
        guard let dob = dateOfBirth else { return .regular }
        let fyStart = DateComponents(year: financialYear, month: 4, day: 1)
        guard let refDate = Calendar.current.date(from: fyStart) else { return .regular }
        let age = Calendar.current.dateComponents([.year], from: dob, to: refDate).year ?? 0
        if age >= 80 { return .superSenior }
        if age >= 60 { return .senior }
        return .regular
    }

    nonisolated private func slabs(
        for regime: IndiaRegime,
        ageCategory: AgeCategory,
        rules: IndiaTaxRuleTable.YearRules
    ) -> [TaxSlab] {
        switch regime {
        case .newRegime:
            return rules.newRegimeSlabs
        case .oldRegime:
            switch ageCategory {
            case .regular: return rules.oldRegimeByAge.regular
            case .senior: return rules.oldRegimeByAge.senior
            case .superSenior: return rules.oldRegimeByAge.superSenior
            }
        }
    }

    nonisolated private func calculateRebate(
        basicTax: Decimal,
        taxableIncome: Decimal,
        regime: IndiaRegime,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        let rebateRules: IndiaTaxRuleTable.RebateRules
        switch regime {
        case .oldRegime:
            rebateRules = rules.oldRegimeRebate
        case .newRegime:
            rebateRules = rules.newRegimeRebate
        }

        let threshold = rebateRules.threshold
        let cap = rebateRules.cap

        if taxableIncome <= threshold {
            return min(basicTax, cap)
        }

        let excess = taxableIncome - threshold
        return max(0, min(basicTax, cap, basicTax - excess))
    }

    nonisolated private func nominalSurchargeRate(
        grossIncome: Decimal,
        regime: IndiaRegime,
        surcharge: IndiaTaxRuleTable.SurchargeRules
    ) -> Decimal {
        surcharge.nominalRate(grossIncome: grossIncome, regime: regime)
    }

    nonisolated private func rawSurcharge(
        core: TaxCoreAmounts,
        grossIncome: Decimal,
        regime: IndiaRegime,
        yearRules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        let surcharge = yearRules.surcharge
        let rate = nominalSurchargeRate(grossIncome: grossIncome, regime: regime, surcharge: surcharge)
        guard rate > 0 else { return 0 }

        let specialRate = min(rate, surcharge.specialRateCap)
        let ordinaryPart = (core.ordinaryTax * rate / 100).rounded(scale: 2)
        let specialPart = (core.specialRateTax * specialRate / 100).rounded(scale: 2)
        return ordinaryPart + specialPart
    }

    nonisolated private func calculateSurcharge(
        core: TaxCoreAmounts,
        grossIncome: Decimal,
        regime: IndiaRegime,
        yearRules: IndiaTaxRuleTable.YearRules,
        profile: TaxProfile
    ) -> Decimal {
        let preliminary = rawSurcharge(core: core, grossIncome: grossIncome, regime: regime, yearRules: yearRules)
        return applySurchargeMarginalRelief(
            core: core,
            grossIncome: grossIncome,
            preliminarySurcharge: preliminary,
            yearRules: yearRules,
            profile: profile
        )
    }

    /// Caps incremental (income tax + surcharge) **before cess** at gross income above the
    /// crossed surcharge threshold — statutory ordering; cess is applied afterward (A13).
    nonisolated private func applySurchargeMarginalRelief(
        core: TaxCoreAmounts,
        grossIncome: Decimal,
        preliminarySurcharge: Decimal,
        yearRules: IndiaTaxRuleTable.YearRules,
        profile: TaxProfile
    ) -> Decimal {
        guard let threshold = yearRules.surcharge.thresholds.last(where: { grossIncome > $0 }) else {
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
            surcharge = calculateSurcharge(
                core: core,
                grossIncome: totalGross,
                regime: input.regime,
                yearRules: input.yearRules,
                profile: adjusted
            )
        } else {
            surcharge = rawSurcharge(
                core: core,
                grossIncome: totalGross,
                regime: input.regime,
                yearRules: input.yearRules
            )
        }
        return core.taxAfterRebate + surcharge
    }

    nonisolated private static func supportedFinancialYear(for profile: TaxProfile) -> Int {
        let parsedYear = Int(profile.financialYear.prefix(4)) ?? IndiaTaxRuleTable.latestFinancialYear
        return IndiaTaxRuleTable.resolvedFinancialYear(parsedYear, in: IndiaTaxRuleTable.financialYears)
    }
}
