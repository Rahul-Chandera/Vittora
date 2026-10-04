import Foundation
import VittoraCore

/// US federal income tax calculator with year-aware federal rules.
/// Supports tax years 2024–2026.
///
/// Order (review 2026-10-03, US-01..US-04):
/// 1. gross income = wages/business income + other investment income +
///    net capital gains (losses netted, net loss limited to $3,000) +
///    qualified dividends;
/// 2. above-the-line: traditional 401(k)/HSA (capped), half of SE tax;
/// 3. deduction: standard (+ aged increment) or itemized, then the enhanced
///    senior deduction, which applies with either;
/// 4. taxable income is split: preferential income first fills what the
///    deduction left, ordinary income is the rest;
/// 5. ordinary brackets + 0/15/20% stacking, never more than regular tax.
struct USTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .unitedStates

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        calculate(profile: profile, deductionMode: .bestAvailable)
    }

    nonisolated func calculate(profile: TaxProfile, deductionMode: USDeductionMode) -> TaxEstimate {
        let status = profile.filingStatus
        let gross = max(0, profile.annualIncome)
        let adv = profile.advancedInputs
        let requestedYear = Self.requestedTaxYear(for: profile)
        let taxYear = Self.supportedTaxYear(for: profile)
        let yearRules = USTaxRuleTable.rules(for: taxYear)
        let isSelfEmployed = profile.incomeSourceType == .selfEmployed
        let age = USContributionHeadroomEngine.ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear)
        let is65OrOver = (age ?? 0) >= 65

        // MARK: Income

        let gains = Self.netCapitalGains(
            shortTerm: adv.usShortTermCapitalGains,
            longTerm: adv.usLongTermCapitalGains,
            status: status
        )
        let qualifiedDividends = max(0, adv.usQualifiedDividends)
        let otherInvestmentIncome = max(0, adv.usOtherInvestmentIncome)
        // Preferential income: net capital gain (long-term part) plus
        // qualified dividends.
        let preferentialIncome = gains.preferential + qualifiedDividends

        // Pre-tax contributions are exclusions/above-the-line, capped at the
        // statutory limit so an over-entered figure never flatters the bill.
        // IRA is deliberately absent: deductibility depends on workplace-plan
        // coverage, which Vittora does not know.
        let preTaxContributions = preTaxContributions(profile: profile, taxYear: taxYear)

        let selfEmployment = isSelfEmployed
            ? Self.selfEmploymentTax(netProfit: gross, status: status, rules: yearRules)
            : nil
        let halfSETax = selfEmployment.map { ($0.total / 2).rounded(scale: 2) } ?? 0

        let ordinaryIncome = max(0, gross + otherInvestmentIncome + gains.ordinary - preTaxContributions - halfSETax)
        let adjustedGrossIncome = ordinaryIncome + preferentialIncome

        // MARK: Deductions

        var standardDeduction = Self.standardDeduction(for: status, taxYear: taxYear)
        if is65OrOver {
            standardDeduction += Self.agedIncrement(for: status, rules: yearRules)
        }
        let itemizedDeductions = profile.customDeductions.reduce(Decimal(0)) { $0 + max(0, $1.amount) }
        let deductionSelection = selectDeduction(
            standardDeduction: standardDeduction,
            itemizedDeductions: itemizedDeductions,
            deductionMode: deductionMode
        )
        let enhancedSenior = Self.enhancedSeniorDeduction(
            eligible: is65OrOver,
            magi: adjustedGrossIncome,
            status: status,
            rules: yearRules
        )

        // MARK: Taxable income split

        let totalTaxable = max(0, adjustedGrossIncome - deductionSelection.appliedDeduction - enhancedSenior)
        let taxablePreferential = min(preferentialIncome, totalTaxable)
        let taxableOrdinary = totalTaxable - taxablePreferential

        let slabs = Self.brackets(for: status, taxYear: taxYear)
        let bracketResults = slabs.apply(to: taxableOrdinary)
        let ordinaryFederalTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        let preferentialTax = Self.preferentialCapitalGainsTax(
            amount: taxablePreferential,
            ordinaryTaxable: taxableOrdinary,
            status: status,
            taxYear: taxYear
        )
        // Qualified-dividend worksheet: never more than regular tax on all of it.
        let regularTaxOnAll = slabs.apply(to: totalTaxable).reduce(Decimal(0)) { $0 + $1.taxAmount }
        let incomeTaxBeforeNIIT = min(ordinaryFederalTax + preferentialTax, regularTaxOnAll)

        let netInvestmentIncome = gains.preferential + max(0, gains.ordinary) + qualifiedDividends + otherInvestmentIncome
        let niit = Self.netInvestmentIncomeTax(
            magi: adjustedGrossIncome,
            netInvestmentIncome: netInvestmentIncome,
            status: status,
            taxYear: taxYear
        )

        // MARK: Payroll

        var supplementary: [TaxSupplementaryLine]
        if let selfEmployment {
            supplementary = [
                TaxSupplementaryLine(title: String(localized: "Self-employment tax"), amount: selfEmployment.total),
            ]
            if selfEmployment.additionalMedicare > 0 {
                supplementary.append(TaxSupplementaryLine(title: String(localized: "Additional Medicare Tax"), amount: selfEmployment.additionalMedicare))
            }
        } else {
            // Gross, not the reduced figure: a 401(k) deferral is still wages for
            // Social Security and Medicare.
            supplementary = Self.payrollTaxes(wages: gross, status: status, taxYear: taxYear).lines
        }

        let incomeTaxTotal = (incomeTaxBeforeNIIT + niit).rounded(scale: 2)
        let totalDenominator = max(adjustedGrossIncome, 1)
        let effectiveRate = (incomeTaxTotal / totalDenominator).rounded(scale: 4)
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        supplementary += USContributionHeadroomEngine.supplementaryHeadroomLines(profile: profile, taxYear: taxYear)

        var assumptions: [String] = [
            isSelfEmployed
                ? String(localized: "Annual income treated as net self-employment profit: self-employment tax is charged on 92.35% of it, and half is deducted.")
                : String(localized: "Annual income treated as wages for Social Security and Medicare estimates unless you adjust advanced inputs.")
        ]
        if preTaxContributions > 0 {
            assumptions.append(String(localized: "Traditional 401(k) and direct HSA contributions reduce income tax but not Social Security and Medicare. HSA contributions through a payroll cafeteria plan would reduce those too."))
        }
        if adv.us401kIsRoth, adv.us401kYTDContributed > 0 {
            assumptions.append(String(localized: "Roth 401(k) contributions are made after tax, so they do not reduce this estimate."))
        }
        if preferentialIncome > 0 {
            assumptions.append(String(localized: "Long-term gains and qualified dividends are modeled with status/year 0/15/20% bracket stacking against ordinary taxable income."))
        }
        if otherInvestmentIncome > 0 {
            assumptions.append(String(localized: "Other investment income (interest, non-qualified dividends) is taxed as ordinary income in addition to your annual income."))
        }
        if netInvestmentIncome > 0 {
            assumptions.append(String(localized: "Net Investment Income Tax uses a simplified MAGI model."))
        }

        var warnings: [String] = []
        if is65OrOver {
            if enhancedSenior > 0 || yearRules.enhancedSeniorDeduction > 0 {
                warnings.append(String(localized: "Age 65+: the additional standard deduction and the up-to-$6,000 senior deduction are applied for you only. A spouse aged 65+ would add their own; married filing separately is not eligible for the senior deduction."))
            }
        }
        if status == .marriedFilingJointly, !isSelfEmployed {
            warnings.append(String(localized: "Social Security is capped per worker. A joint estimate applies one cap to combined wages, which understates it when both spouses earn."))
        }
        if taxYear >= 2026, (age ?? 0) >= 50, adv.us401kYTDContributed > 0, !adv.us401kIsRoth {
            warnings.append(String(localized: "From 2026, if your prior-year wages from this employer exceeded $150,000, 401(k) catch-up contributions must be Roth and do not reduce income tax."))
        }
        if gains.disallowedLoss > 0 {
            warnings.append(String(localized: "Net capital loss above the yearly limit carries forward and is not used this year."))
        }
        if !USTaxRuleTable.isHeld(requestedYear) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        var exclusions = [
            String(localized: "Alternative Minimum Tax (AMT) is not calculated."),
            TaxDisclaimer.usFederalEstimateLabel,
            String(localized: "Payroll taxes are shown separately and are not included in the federal income tax total."),
            String(localized: "Tax credits, the QBI deduction and the tips, overtime and car-loan interest deductions are not calculated."),
        ]
        if adv.usIRAYTDContributed > 0 {
            exclusions.append(String(localized: "Traditional IRA deductions are not applied: deductibility phases out with income when a workplace retirement plan covers you, which Vittora does not know."))
        }

        // The displayed bridge reconciles: total income − standard (incl. senior)
        // − other deductions (itemized + pre-tax contributions + half SE tax)
        // = taxable income (review SH-02).
        let totalIncome = gross + otherInvestmentIncome + gains.ordinary + preferentialIncome
        return TaxEstimate(
            grossIncome: totalIncome,
            standardDeduction: deductionSelection.standardDeductionPortion + enhancedSenior,
            customDeductionsTotal: deductionSelection.customDeductionsPortion + preTaxContributions + halfSETax,
            taxableIncome: totalTaxable,
            bracketResults: bracketResults,
            basicTax: ordinaryFederalTax,
            rebate: 0,
            surcharge: 0,
            cess: 0,
            finalTax: incomeTaxTotal,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate,
            country: .unitedStates,
            regimeLabel: regimeLabel(for: status, deductionMode: deductionMode),
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.us.v1",
            ruleSetID: "US_FEDERAL_TY\(taxYear)",
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }

    nonisolated private static let rulesLastUpdated: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 3)) ?? .distantPast
    }()

    /// Contributions that reduce federal taxable income, each capped at its
    /// age-aware statutory limit. 401(k) only when traditional; HSA always;
    /// IRA never.
    nonisolated func preTaxContributions(profile: TaxProfile, taxYear: Int) -> Decimal {
        let adv = profile.advancedInputs
        let age = USContributionHeadroomEngine.ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear)

        var total: Decimal = 0
        if !adv.us401kIsRoth {
            let limit = USContributionHeadroomEngine.statutory401kLimit(taxYear: taxYear, age: age)
            total += min(max(0, adv.us401kYTDContributed), limit)
        }
        let hsaLimit = USContributionHeadroomEngine.statutoryHSALimit(
            taxYear: taxYear,
            familyCoverage: adv.usHSAFamilyCoverage,
            age: age
        )
        total += min(max(0, adv.usHSAYTDContributed), hsaLimit)
        return total
    }

    // MARK: - Components

    nonisolated private static func agedIncrement(for status: USFilingStatus, rules: USTaxRuleTable.YearRules) -> Decimal {
        switch status {
        case .single, .headOfHousehold:
            rules.agedAdditionalStandardDeductionUnmarried
        case .marriedFilingJointly, .marriedFilingSeparately, .qualifyingSurvivingSpouse:
            rules.agedAdditionalStandardDeductionMarried
        }
    }

    /// Up to the yearly amount for an eligible taxpayer 65+, less 6% of MAGI
    /// over $75,000 ($150,000 joint). Married filing separately is ineligible.
    nonisolated private static func enhancedSeniorDeduction(
        eligible: Bool,
        magi: Decimal,
        status: USFilingStatus,
        rules: USTaxRuleTable.YearRules
    ) -> Decimal {
        guard eligible, rules.enhancedSeniorDeduction > 0, status != .marriedFilingSeparately else { return 0 }
        let excess = max(0, magi - USTaxRuleTable.enhancedSeniorPhaseOutStart(for: status))
        let reduction = (excess * USTaxRuleTable.enhancedSeniorPhaseOutRate).rounded(scale: 2)
        return max(0, rules.enhancedSeniorDeduction - reduction)
    }

    struct NetGains: Sendable {
        /// Taxed at ordinary rates: net short-term gain, or the allowed net loss (negative).
        nonisolated let ordinary: Decimal
        /// Net capital gain eligible for 0/15/20%.
        nonisolated let preferential: Decimal
        /// Net loss beyond the yearly limit, carried forward.
        nonisolated let disallowedLoss: Decimal
    }

    /// Nets short- and long-term results the way Schedule D does: net capital
    /// gain is the smaller of net long-term gain and total net gain; a net loss
    /// is deductible up to $3,000 ($1,500 married filing separately).
    nonisolated static func netCapitalGains(shortTerm: Decimal, longTerm: Decimal, status: USFilingStatus) -> NetGains {
        let net = shortTerm + longTerm
        if net <= 0 {
            let limit: Decimal = status == .marriedFilingSeparately ? 1_500 : 3_000
            let allowed = min(-net, limit)
            return NetGains(ordinary: -allowed, preferential: 0, disallowedLoss: -net - allowed)
        }
        let preferential = max(0, min(longTerm, net))
        return NetGains(ordinary: net - preferential, preferential: preferential, disallowedLoss: 0)
    }

    struct SelfEmploymentTax: Sendable {
        nonisolated let socialSecurity: Decimal
        nonisolated let medicare: Decimal
        nonisolated let additionalMedicare: Decimal
        /// SE tax proper (Social Security + Medicare); Additional Medicare Tax is
        /// separate and not half-deductible.
        nonisolated var total: Decimal { socialSecurity + medicare }
    }

    /// 15.3% on 92.35% of net profit: 12.4% up to the wage base, 2.9% on all,
    /// plus 0.9% Additional Medicare over the status threshold.
    nonisolated static func selfEmploymentTax(
        netProfit: Decimal,
        status: USFilingStatus,
        rules: USTaxRuleTable.YearRules
    ) -> SelfEmploymentTax {
        let earningsFactor = Decimal(string: "0.9235") ?? 0
        let netEarnings = (max(0, netProfit) * earningsFactor).rounded(scale: 2)
        // $400 floor: no SE tax below it.
        guard netEarnings >= 400 else { return SelfEmploymentTax(socialSecurity: 0, medicare: 0, additionalMedicare: 0) }
        let socialSecurity = (min(netEarnings, rules.socialSecurityWageBase) * rules.socialSecurityRate * 2).rounded(scale: 2)
        let medicare = (netEarnings * rules.medicareRate * 2).rounded(scale: 2)
        let threshold = rules.byStatus[status].additionalMedicareThreshold
        let additional = (max(0, netEarnings - threshold) * rules.additionalMedicareRate).rounded(scale: 2)
        return SelfEmploymentTax(socialSecurity: socialSecurity, medicare: medicare, additionalMedicare: additional)
    }

    private struct PayrollBreakdown {
        let lines: [TaxSupplementaryLine]
    }

    nonisolated private static func payrollTaxes(wages: Decimal, status: USFilingStatus, taxYear: Int) -> PayrollBreakdown {
        let yearRules = USTaxRuleTable.rules(for: taxYear)
        let statusRules = yearRules.byStatus[status]
        let ss = (min(wages, yearRules.socialSecurityWageBase) * yearRules.socialSecurityRate).rounded(scale: 2)
        let medicare = (wages * yearRules.medicareRate).rounded(scale: 2)
        let additionalMedicare = (max(0, wages - statusRules.additionalMedicareThreshold) * yearRules.additionalMedicareRate).rounded(scale: 2)
        let lines = [
            TaxSupplementaryLine(title: String(localized: "Social Security (employee)"), amount: ss),
            TaxSupplementaryLine(title: String(localized: "Medicare (employee)"), amount: medicare),
            TaxSupplementaryLine(title: String(localized: "Additional Medicare Tax"), amount: additionalMedicare)
        ]
        return PayrollBreakdown(lines: lines)
    }

    nonisolated private static func netInvestmentIncomeTax(
        magi: Decimal,
        netInvestmentIncome: Decimal,
        status: USFilingStatus,
        taxYear: Int
    ) -> Decimal {
        guard netInvestmentIncome > 0 else { return 0 }
        let yearRules = USTaxRuleTable.rules(for: taxYear)
        let threshold = yearRules.byStatus[status].niitThreshold
        guard magi > threshold else { return 0 }
        let base = min(netInvestmentIncome, magi - threshold)
        return (max(0, base) * yearRules.niitRate).rounded(scale: 2)
    }

    /// 0/15/20% stacked on top of ordinary TAXABLE income — `amount` must be the
    /// taxable preferential income, after the deduction has been allocated.
    nonisolated private static func preferentialCapitalGainsTax(
        amount: Decimal,
        ordinaryTaxable: Decimal,
        status: USFilingStatus,
        taxYear: Int
    ) -> Decimal {
        guard amount > 0 else { return 0 }
        let yearRules = USTaxRuleTable.rules(for: taxYear)
        let statusRules = yearRules.byStatus[status]

        let zeroRateCapacity = max(0, statusRules.preferentialZeroRateUpperBound - ordinaryTaxable)
        let zeroRatePortion = min(amount, zeroRateCapacity)

        let amountRemainingAfterZeroRate = amount - zeroRatePortion
        let fifteenRateStart = max(ordinaryTaxable, statusRules.preferentialZeroRateUpperBound)
        let fifteenRateCapacity = max(0, statusRules.preferentialFifteenRateUpperBound - fifteenRateStart)
        let fifteenRatePortion = min(amountRemainingAfterZeroRate, fifteenRateCapacity)

        let twentyRatePortion = max(0, amountRemainingAfterZeroRate - fifteenRatePortion)

        let fifteenRateTax = (fifteenRatePortion * yearRules.preferentialFifteenRate)
        let twentyRateTax = (twentyRatePortion * yearRules.preferentialTwentyRate)
        return (fifteenRateTax + twentyRateTax).rounded(scale: 2)
    }

    nonisolated private func selectDeduction(
        standardDeduction: Decimal,
        itemizedDeductions: Decimal,
        deductionMode: USDeductionMode
    ) -> USDeductionSelection {
        switch deductionMode {
        case .bestAvailable:
            if itemizedDeductions > standardDeduction {
                USDeductionSelection(
                    appliedDeduction: itemizedDeductions,
                    standardDeductionPortion: 0,
                    customDeductionsPortion: itemizedDeductions
                )
            } else {
                USDeductionSelection(
                    appliedDeduction: standardDeduction,
                    standardDeductionPortion: standardDeduction,
                    customDeductionsPortion: 0
                )
            }
        case .standardOnly:
            USDeductionSelection(
                appliedDeduction: standardDeduction,
                standardDeductionPortion: standardDeduction,
                customDeductionsPortion: 0
            )
        case .itemizedOnly:
            USDeductionSelection(
                appliedDeduction: itemizedDeductions,
                standardDeductionPortion: 0,
                customDeductionsPortion: itemizedDeductions
            )
        }
    }

    nonisolated private func regimeLabel(for status: USFilingStatus, deductionMode: USDeductionMode) -> String {
        switch deductionMode {
        case .bestAvailable:
            status.displayName
        case .standardOnly:
            String(localized: "\(status.displayName) · Standard Deduction")
        case .itemizedOnly:
            String(localized: "\(status.displayName) · Itemized Deductions")
        }
    }

    nonisolated static func standardDeduction(for status: USFilingStatus, taxYear: Int) -> Decimal {
        USTaxRuleTable.rules(for: taxYear).byStatus[status].standardDeduction
    }

    nonisolated static func brackets(for status: USFilingStatus, taxYear: Int) -> [TaxSlab] {
        USTaxRuleTable.rules(for: taxYear).byStatus[status].brackets
    }

    nonisolated static func requestedTaxYear(for profile: TaxProfile) -> Int {
        Int(profile.financialYear.prefix(4)) ?? USTaxRuleTable.latestTaxYear
    }

    /// The year whose rules were actually applied. The rule-set ID and the
    /// age/limit lookups all use this, so an unsupported year can no longer be
    /// labelled with rules it did not use.
    nonisolated static func supportedTaxYear(for profile: TaxProfile) -> Int {
        USTaxRuleTable.resolvedTaxYear(requestedTaxYear(for: profile), in: USTaxRuleTable.heldYears)
    }
}

enum USDeductionMode: Sendable {
    case bestAvailable
    case standardOnly
    case itemizedOnly
}

private struct USDeductionSelection {
    let appliedDeduction: Decimal
    let standardDeductionPortion: Decimal
    let customDeductionsPortion: Decimal
}
