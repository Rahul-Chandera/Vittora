import Foundation
import VittoraCore

/// India income tax calculator with year-aware resident-individual rules.
///
/// The order is statutory and explicit (review 2026-10-03, IN-01..IN-06):
///
/// 1. ordinary taxable income = income − salary standard deduction − allowed
///    deductions (old regime: Chapter VI-A + HRA; both regimes: employer NPS);
/// 2. resident basic-exemption shortfall is set against equity gains
///    (§111A/§112A provisos), STCG first because it is taxed at the higher rate;
/// 3. TOTAL income — ordinary plus the full gains — decides rebate eligibility
///    and the surcharge rate;
/// 4. the §87A rebate offsets only what its regime allows; the new-regime rebate
///    has marginal relief, the old-regime one is a cliff;
/// 5. surcharge, with marginal relief computed at the total-income threshold;
/// 6. cess last.
struct IndiaTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .india

    /// Everything that varies per scenario. The surcharge marginal-relief
    /// comparator builds one of these at the threshold rather than re-running
    /// the profile with a substituted salary, which double-added the gains.
    private struct Scenario: Sendable {
        nonisolated let ordinaryTaxable: Decimal
        nonisolated let stcg: Decimal
        nonisolated let ltcg: Decimal
    }

    private struct CoreAmounts: Sendable {
        nonisolated let bracketResults: [TaxBracketResult]
        nonisolated let basicTax: Decimal
        nonisolated let stcgTax: Decimal
        nonisolated let ltcgTax: Decimal
        nonisolated let rebate: Decimal
        nonisolated let totalIncome: Decimal

        /// Rebate applies to slab tax first; any remainder (old regime only) to
        /// STCG tax. Surcharge rates differ between the two, so keep them apart.
        nonisolated var ordinaryAfterRebate: Decimal { max(0, basicTax - rebate) }
        nonisolated var specialAfterRebate: Decimal { max(0, stcgTax + ltcgTax - max(0, rebate - basicTax)) }
        nonisolated var taxAfterRebate: Decimal { ordinaryAfterRebate + specialAfterRebate }
        nonisolated var marginalRate: Decimal { bracketResults.last?.ratePercent ?? 0 }
    }

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        let requestedYear = Self.requestedFinancialYear(for: profile)
        let rulesYear = IndiaTaxRuleTable.resolvedFinancialYear(requestedYear, in: IndiaTaxRuleTable.financialYears)
        let rules = IndiaTaxRuleTable.rules(for: rulesYear)
        let regime = profile.indiaRegime
        let adv = profile.advancedInputs
        let gross = max(0, profile.annualIncome)

        let standardDeduction = Self.standardDeduction(for: regime, incomeSourceType: profile.incomeSourceType, rules: rules)
        let deductionResolution = IndiaSectionDeductionEngine.resolve(
            deductions: profile.customDeductions,
            advancedInputs: adv,
            dateOfBirth: profile.dateOfBirth,
            financialYearLabel: profile.financialYear,
            incomeSourceType: profile.incomeSourceType,
            employerNPSRate: regime == .newRegime ? rules.employerNPSNewRegimeRate : rules.employerNPSOldRegimeRate
        )
        // Most personal deductions are old-regime only; employer NPS is allowed
        // in both. The salary deduction cannot exceed the salary itself.
        let personalDeductions = regime == .oldRegime ? deductionResolution.allowedTotal : 0
        let appliedStandardDeduction = min(standardDeduction, gross)
        let customDeductionsTotal = personalDeductions + deductionResolution.employerNPS
        let ordinaryTaxable = max(0, gross - appliedStandardDeduction - customDeductionsTotal)

        let ageCategory = Self.ageCategory(dateOfBirth: profile.dateOfBirth, financialYear: requestedYear)
        let scenario = Scenario(
            ordinaryTaxable: ordinaryTaxable,
            stcg: max(0, adv.indiaEquitySTCG),
            ltcg: max(0, adv.indiaEquityLTCG)
        )
        let core = Self.coreAmounts(scenario: scenario, regime: regime, ageCategory: ageCategory, rules: rules)
        let surcharge = Self.surcharge(core: core, scenario: scenario, regime: regime, ageCategory: ageCategory, rules: rules)
        let cess = ((core.taxAfterRebate + surcharge) * rules.cessRate).rounded(scale: 2)
        let finalTax = (core.taxAfterRebate + surcharge + cess).rounded(scale: 2)

        // Denominator: total income received, gains in full.
        let economicIncome = gross + scenario.stcg + scenario.ltcg
        let effectiveRate = economicIncome > 0 ? (finalTax / economicIncome).rounded(scale: 4) : 0

        var supplementary: [TaxSupplementaryLine] = []
        if core.ltcgTax > 0 {
            supplementary.append(TaxSupplementaryLine(title: String(localized: "Equity LTCG (Section 112A-style)"), amount: core.ltcgTax))
        }
        if core.stcgTax > 0 {
            supplementary.append(TaxSupplementaryLine(title: String(localized: "Equity STCG (simplified)"), amount: core.stcgTax))
        }

        var assumptions: [String] = [
            String(localized: "Ordinary income is slab-taxed; equity LTCG/STCG use simplified rates and exemptions.")
        ]
        if scenario.stcg > 0 || scenario.ltcg > 0 {
            assumptions.append(String(localized: "Resident individual: any unused basic exemption is set against equity gains before they are taxed."))
        }

        var warnings: [String] = []
        if scenario.stcg > 0 || scenario.ltcg > 0 {
            warnings.append(regime == .oldRegime
                ? String(localized: "Old regime: the Section 87A rebate can offset short-term equity gain tax, but not long-term gain tax (Section 112A).")
                : String(localized: "New regime: the Section 87A rebate offsets slab tax only, not tax on equity gains. Eligibility counts the gains in total income."))
            if core.totalIncome > rules.surcharge.specialRateCapWarningThreshold {
                warnings.append(String(localized: "Surcharge on equity LTCG/STCG is capped at 15% under Sections 111A/112A-style modeling."))
            }
            if rulesYear == 2024 {
                warnings.append(String(localized: "FY 2024-25: equity sold before 23 July 2024 was taxed at 15% (STCG) and 10% (LTCG). This estimate applies the later 20% and 12.5% rates to all gains."))
            }
        }
        if regime == .oldRegime || deductionResolution.employerNPS > 0 {
            warnings.append(contentsOf: deductionResolution.warnings)
        }
        if !IndiaTaxRuleTable.isHeld(requestedYear) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        let exclusions: [String] = [
            String(localized: "State taxes and cess on surcharges are modeled only at the federal level; verify with a CA."),
            String(localized: "Tax is shown to the paisa; the return rounds income and tax payable to the nearest ₹10."),
            String(localized: "Non-resident rules are not applied."),
        ]

        // Reconciling bridges (review SH-02): income includes the gains, taxable
        // income is total income, and basic tax includes the special-rate gain
        // tax — so "basic − rebate + surcharge + cess" is the final figure.
        return TaxEstimate(
            grossIncome: economicIncome,
            standardDeduction: appliedStandardDeduction,
            customDeductionsTotal: customDeductionsTotal,
            taxableIncome: core.totalIncome,
            bracketResults: core.bracketResults,
            basicTax: core.basicTax + core.stcgTax + core.ltcgTax,
            rebate: core.rebate,
            surcharge: surcharge,
            cess: cess,
            finalTax: finalTax,
            effectiveRate: effectiveRate,
            marginalRate: core.marginalRate,
            country: .india,
            regimeLabel: regime.displayName,
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.in.v1",
            ruleSetID: rules.ruleSetID,
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }

    nonisolated private static let rulesLastUpdated: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 3)) ?? .distantPast
    }()

    // MARK: - Core

    nonisolated private static func coreAmounts(
        scenario: Scenario,
        regime: IndiaRegime,
        ageCategory: AgeCategory,
        rules: IndiaTaxRuleTable.YearRules
    ) -> CoreAmounts {
        let slabs = slabs(for: regime, ageCategory: ageCategory, rules: rules)
        let bracketResults = slabs.apply(to: scenario.ordinaryTaxable)
        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        // Basic-exemption shortfall (resident individuals). The exemption limit
        // is the width of the 0% slab for this regime and age.
        let exemptionLimit = slabs.first.flatMap { $0.ratePercent == 0 ? $0.upper : nil } ?? 0
        var shortfall = max(0, exemptionLimit - scenario.ordinaryTaxable)
        let stcgAfterShortfall = max(0, scenario.stcg - shortfall)
        shortfall = max(0, shortfall - scenario.stcg)
        let ltcgAfterShortfall = max(0, scenario.ltcg - shortfall)

        let stcgTax = (stcgAfterShortfall * rules.equitySTCGRate).rounded(scale: 2)
        // §112A: the ₹1.25 lakh is a rate threshold on what remains, not a
        // deduction from total income.
        let ltcgTax = (max(0, ltcgAfterShortfall - rules.equityLTCGExemption) * rules.equityLTCGRate).rounded(scale: 2)

        let totalIncome = scenario.ordinaryTaxable + scenario.stcg + scenario.ltcg
        let rebateRules = regime == .oldRegime ? rules.oldRegimeRebate : rules.newRegimeRebate
        let rebate = rebate(
            basicTax: basicTax,
            stcgTax: stcgTax,
            ltcgTax: ltcgTax,
            totalIncome: totalIncome,
            rules: rebateRules
        )

        return CoreAmounts(
            bracketResults: bracketResults,
            basicTax: basicTax,
            stcgTax: stcgTax,
            ltcgTax: ltcgTax,
            rebate: rebate,
            totalIncome: totalIncome
        )
    }

    nonisolated private static func rebate(
        basicTax: Decimal,
        stcgTax: Decimal,
        ltcgTax: Decimal,
        totalIncome: Decimal,
        rules: IndiaTaxRuleTable.RebateRules
    ) -> Decimal {
        let eligibleTax = basicTax + (rules.coversShortTermGainTax ? stcgTax : 0)
        if totalIncome <= rules.threshold {
            return min(eligibleTax, rules.cap)
        }
        guard rules.hasMarginalRelief else { return 0 }
        // Marginal relief: total tax may not exceed the income above the
        // threshold. It reduces slab tax only.
        let taxBeforeRelief = basicTax + stcgTax + ltcgTax
        let excess = totalIncome - rules.threshold
        return max(0, min(basicTax, taxBeforeRelief - excess))
    }

    // MARK: - Surcharge

    nonisolated private static func rawSurcharge(
        core: CoreAmounts,
        regime: IndiaRegime,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        let rate = rules.surcharge.nominalRate(grossIncome: core.totalIncome, regime: regime)
        guard rate > 0 else { return 0 }
        let specialRate = min(rate, rules.surcharge.specialRateCap)
        let ordinaryPart = (core.ordinaryAfterRebate * rate / 100).rounded(scale: 2)
        let specialPart = (core.specialAfterRebate * specialRate / 100).rounded(scale: 2)
        return ordinaryPart + specialPart
    }

    /// Caps (tax + surcharge) before cess at tax on income equal to the crossed
    /// threshold plus the income above it. The comparator is built at the
    /// threshold TOTAL income, holding the gains fixed and reducing ordinary
    /// income — so the gains are counted once, not added again on top.
    nonisolated private static func surcharge(
        core: CoreAmounts,
        scenario: Scenario,
        regime: IndiaRegime,
        ageCategory: AgeCategory,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        let preliminary = rawSurcharge(core: core, regime: regime, rules: rules)
        guard preliminary > 0,
              let threshold = rules.surcharge.thresholds.last(where: { core.totalIncome > $0 })
        else { return preliminary }

        // Gains larger than the threshold: trim LTCG, then STCG, to fit.
        let gains = scenario.stcg + scenario.ltcg
        var ltcgAtThreshold = scenario.ltcg
        var stcgAtThreshold = scenario.stcg
        if gains > threshold {
            stcgAtThreshold = min(scenario.stcg, threshold)
            ltcgAtThreshold = min(scenario.ltcg, threshold - stcgAtThreshold)
        }
        let atThreshold = Scenario(
            ordinaryTaxable: max(0, threshold - stcgAtThreshold - ltcgAtThreshold),
            stcg: stcgAtThreshold,
            ltcg: ltcgAtThreshold
        )
        let coreAtThreshold = coreAmounts(scenario: atThreshold, regime: regime, ageCategory: ageCategory, rules: rules)
        // At exactly the threshold the lower rung's surcharge (if any) applies.
        let preCessAtThreshold = coreAtThreshold.taxAfterRebate + rawSurcharge(core: coreAtThreshold, regime: regime, rules: rules)
        let ceiling = preCessAtThreshold + (core.totalIncome - threshold)

        guard core.taxAfterRebate + preliminary > ceiling else { return preliminary }
        return max(0, ceiling - core.taxAfterRebate).rounded(scale: 2)
    }

    // MARK: - Rules

    private enum AgeCategory {
        case regular      // under 60
        case senior       // 60–79
        case superSenior  // 80+
    }

    nonisolated private static func standardDeduction(
        for regime: IndiaRegime,
        incomeSourceType: IncomeSourceType,
        rules: IndiaTaxRuleTable.YearRules
    ) -> Decimal {
        guard incomeSourceType == .salaried else { return 0 }
        switch regime {
        case .newRegime: return rules.newRegimeSalariedStandardDeduction
        case .oldRegime: return rules.oldRegimeSalariedStandardDeduction
        }
    }

    /// Senior status is age attained at ANY time in the requested year — not on
    /// 1 April, and not in whichever year the rule table resolved to.
    nonisolated private static func ageCategory(dateOfBirth: Date?, financialYear: Int) -> AgeCategory {
        guard let age = IndiaTaxAge.attainedAge(dateOfBirth: dateOfBirth, financialYear: financialYear) else {
            return .regular
        }
        if age >= 80 { return .superSenior }
        if age >= 60 { return .senior }
        return .regular
    }

    nonisolated private static func slabs(
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

    nonisolated private static func requestedFinancialYear(for profile: TaxProfile) -> Int {
        Int(profile.financialYear.prefix(4)) ?? IndiaTaxRuleTable.latestFinancialYear
    }
}
