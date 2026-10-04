import Foundation
import VittoraCore

/// Canadian federal and provincial income tax, CPP/QPP/EI and capital gains.
///
/// Order (review 2026-10-03, CA-01..CA-06):
///
/// 1. CPP or QPP and EI come FIRST, because they change income tax: the
///    enhanced contribution (1% of the first tier, all of CPP2/QPP2) is a
///    deduction (line 22215); the base contribution and EI premiums are
///    non-refundable credits. Self-employed people pay both shares, deduct the
///    employer-equivalent half (line 22200), and pay no EI unless they opt in.
/// 2. Net income = income + taxable half of gains − RRSP − other deductions −
///    those contribution deductions. Taxable income = net income here.
/// 3. Federal and provincial brackets apply to the same taxable income.
/// 4. Each level's basic personal amount (reduced with net income where the
///    jurisdiction does so) and the contribution credits are valued at that
///    level's lowest rate.
/// 5. Ontario's surtax is charged on its own tax, after credits.
/// 6. Quebec reduces basic federal tax by the 16.5% abatement.
nonisolated struct CATaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .canada

    nonisolated static let rulesLastUpdated: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 3
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        let adv = profile.advancedInputs
        let taxYear = Self.supportedTaxYear(for: profile)
        let rules = CATaxRuleTable.rules(for: taxYear)
        let province = adv.caProvince
        let isQuebec = province == .quebec
        let isSelfEmployed = profile.incomeSourceType == .selfEmployed

        let earnings = max(0, profile.annualIncome)

        // Half of a capital gain is included in income.
        let taxableCapitalGain = (max(0, adv.caCapitalGains)
            * rules.capitalGainsInclusionPercent / 100).rounded(scale: 2)

        // MARK: Contributions (first — they change the tax)

        let plan = isQuebec ? rules.qpp : rules.cpp
        let pension = Self.pensionContribution(earnings: earnings, plan: plan, selfEmployed: isSelfEmployed)
        let ei = isSelfEmployed ? 0 : Self.eiPremium(employmentIncome: earnings, province: province, rules: rules)

        let rrsp = max(0, adv.caRRSPContributions)
        let otherDeductions = profile.customDeductions.reduce(Decimal(0)) { $0 + max(0, $1.amount) }
        let deductions = rrsp + otherDeductions + pension.deduction

        let taxableIncome = max(0, earnings + taxableCapitalGain - deductions)
        let netIncome = taxableIncome

        // MARK: Federal

        let federalBPA = Self.federalBasicPersonalAmount(netIncome: netIncome, rules: rules)
        let federalBrackets = rules.federal.brackets.apply(to: taxableIncome)
        let federalGross = federalBrackets.reduce(Decimal(0)) { $0 + $1.taxAmount }
        let federalCreditBase = federalBPA + pension.creditAmount + ei
        let federalCredit = min(federalGross, (federalCreditBase * rules.federal.creditRatePercent / 100).rounded(scale: 2))
        var federalTax = federalGross - federalCredit

        var abatement = Decimal(0)
        if isQuebec {
            abatement = (federalTax * rules.quebecAbatementPercent / 100).rounded(scale: 2)
            federalTax = max(0, federalTax - abatement)
        }

        // MARK: Provincial

        let jurisdiction = rules.provinces[province] ?? rules.federal
        let provincialBPA = Self.provincialBasicPersonalAmount(jurisdiction: jurisdiction, netIncome: netIncome, rules: rules)
        let provincialBrackets = jurisdiction.brackets.apply(to: taxableIncome)
        let provincialGross = provincialBrackets.reduce(Decimal(0)) { $0 + $1.taxAmount }
        // Outside Quebec the provinces mirror the federal contribution credits;
        // Quebec's own return treats QPP/EI differently and is not modelled.
        let provincialCreditBase = provincialBPA + (isQuebec ? 0 : pension.creditAmount + ei)
        let provincialCredit = min(provincialGross, (provincialCreditBase * jurisdiction.creditRatePercent / 100).rounded(scale: 2))
        let provincialBeforeSurtax = provincialGross - provincialCredit
        let surtax = Self.surtax(on: provincialBeforeSurtax, jurisdiction: jurisdiction)
        let provincialTax = provincialBeforeSurtax + surtax

        let finalTax = federalTax + provincialTax + pension.total + ei
        let grossIncome = earnings + taxableCapitalGain

        var supplementary: [TaxSupplementaryLine] = [
            TaxSupplementaryLine(title: String(localized: "Federal tax"), amount: federalTax),
            TaxSupplementaryLine(
                title: String(localized: "\(province.displayName) tax"),
                amount: provincialTax
            ),
        ]
        if surtax > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Provincial surtax"), amount: surtax
            ))
        }
        if abatement > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Quebec federal abatement"), amount: -abatement
            ))
        }
        if pension.total > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: isQuebec
                    ? String(localized: "QPP contribution")
                    : String(localized: "CPP contribution"),
                amount: pension.total
            ))
        }
        if ei > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "EI premium"), amount: ei
            ))
        }

        var assumptions: [String] = [
            String(localized: "Tax year is the calendar year."),
            String(localized: "Resident of \(province.displayName) on 31 December."),
            String(localized: "Basic personal amounts are applied as non-refundable credits, not deductions."),
            String(localized: "Enhanced CPP/QPP contributions are deducted from income; base contributions and EI premiums are claimed as credits."),
        ]
        if isSelfEmployed {
            assumptions.append(String(localized: "Annual income treated as net self-employment income: both shares of CPP/QPP are paid and the employer share is deducted. EI is not charged — it is optional for the self-employed."))
        } else {
            assumptions.append(String(localized: "CPP/QPP and EI are charged on annual income as employment earnings. Pension income does not pay them."))
        }
        if taxableCapitalGain > 0 {
            assumptions.append(String(localized: "Half of your capital gains is included in income."))
        }
        if abatement > 0 {
            assumptions.append(String(localized: "Quebec's 16.5% federal abatement applied."))
        }
        if federalBPA < rules.federal.basicPersonalAmount {
            assumptions.append(String(localized: "Federal basic personal amount reduced to \(Self.plain(federalBPA)) because of income level."))
        }

        var warnings: [String] = []
        if rrsp > 0 {
            warnings.append(String(localized: "RRSP contributions are deducted in full. Your deduction is limited by your RRSP room, which Vittora does not know."))
        }
        if !CATaxRuleTable.supportedYears.contains(Self.requestedTaxYear(for: profile)) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        let exclusions: [String] = [
            String(localized: "Provincial health premiums and levies are not included."),
            String(localized: "Quebec Parental Insurance Plan premiums are not included."),
            String(localized: "Canada Employment Amount and other non-refundable credits are not included."),
            String(localized: "Provincial low-income tax reductions are not included."),
            String(localized: "GST/HST credit, Canada Child Benefit and other refundable credits are not included."),
            String(localized: "Dividend gross-up and dividend tax credits are not modelled."),
        ]

        // Reconciling bridges (review SH-02): the BPA is a credit, not a
        // deduction, so it is not shown as one; basic tax is federal tax before
        // credits, and the credits slot holds federal credits + abatement, so
        // "basic − credits + provincial + contributions" is the final figure.
        return TaxEstimate(
            grossIncome: grossIncome,
            standardDeduction: 0,
            customDeductionsTotal: deductions,
            taxableIncome: taxableIncome,
            bracketResults: federalBrackets,
            basicTax: federalGross,
            rebate: federalCredit + abatement,
            surcharge: provincialTax,
            cess: pension.total + ei,
            finalTax: finalTax,
            effectiveRate: grossIncome > 0 ? (finalTax / grossIncome).rounded(scale: 4) : 0,
            marginalRate: Self.marginalRate(
                taxableIncome: taxableIncome,
                provincialTaxBeforeSurtax: provincialBeforeSurtax,
                jurisdiction: jurisdiction,
                isQuebec: isQuebec,
                rules: rules
            ),
            country: .canada,
            regimeLabel: province.displayName,
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.ca.v1",
            ruleSetID: "\(rules.ruleSetID)_\(province.rawValue)",
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }
}

// MARK: - Components

extension CATaxCalculator {

    /// The federal BPA is clawed back across the top two brackets on NET income
    /// (line 23600), from its maximum down to a floor.
    nonisolated static func federalBasicPersonalAmount(
        netIncome: Decimal,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        linearBPA(
            maximum: rules.federal.basicPersonalAmount,
            minimum: rules.federalBasicPersonalAmountMinimum,
            start: rules.federalBPATaperStart,
            end: rules.federalBPATaperEnd,
            netIncome: netIncome
        )
    }

    nonisolated static func provincialBasicPersonalAmount(
        jurisdiction: CATaxRuleTable.Jurisdiction,
        netIncome: Decimal,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        switch jurisdiction.bpaReduction {
        case .none:
            return jurisdiction.basicPersonalAmount
        case .federal:
            return federalBasicPersonalAmount(netIncome: netIncome, rules: rules)
        case let .linear(start, end, minimum):
            return linearBPA(maximum: jurisdiction.basicPersonalAmount, minimum: minimum, start: start, end: end, netIncome: netIncome)
        }
    }

    nonisolated private static func linearBPA(
        maximum: Decimal,
        minimum: Decimal,
        start: Decimal,
        end: Decimal,
        netIncome: Decimal
    ) -> Decimal {
        if netIncome <= start { return maximum }
        if netIncome >= end { return minimum }
        let span = end - start
        guard span > 0 else { return maximum }
        let progress = (netIncome - start) / span
        return (maximum - (maximum - minimum) * progress).rounded(scale: 2)
    }

    /// Charged on provincial tax, not on income, so it stacks after credits.
    /// Ontario has two rungs and they are cumulative.
    nonisolated static func surtax(
        on provincialTax: Decimal,
        jurisdiction: CATaxRuleTable.Jurisdiction
    ) -> Decimal {
        jurisdiction.surtaxes.reduce(Decimal(0)) { total, surtax in
            guard provincialTax > surtax.threshold else { return total }
            return total + ((provincialTax - surtax.threshold) * surtax.ratePercent / 100).rounded(scale: 2)
        }
    }

    struct PensionContribution: Sendable {
        /// Paid this year (both shares when self-employed).
        nonisolated let total: Decimal
        /// Deducted from income: enhanced part of the employee share, plus the
        /// employer-equivalent share when self-employed.
        nonisolated let deduction: Decimal
        /// Base part of the employee share, claimed as a non-refundable credit.
        nonisolated let creditAmount: Decimal
    }

    /// First tier on earnings between the exemption and the YMPE (base +
    /// enhanced), second tier between the YMPE and the YAMPE (all enhanced).
    /// CPP and QPP share these mechanics but not their rates.
    nonisolated static func pensionContribution(
        earnings: Decimal,
        plan: CATaxRuleTable.PensionPlanRules,
        selfEmployed: Bool
    ) -> PensionContribution {
        guard earnings > plan.basicExemption else {
            return PensionContribution(total: 0, deduction: 0, creditAmount: 0)
        }
        let firstTierEarnings = max(0, min(earnings, plan.maximumPensionableEarnings) - plan.basicExemption)
        let secondTierEarnings = max(0, min(earnings, plan.additionalMaximumPensionableEarnings) - plan.maximumPensionableEarnings)

        let employeeFirst = (firstTierEarnings * plan.ratePercent / 100).rounded(scale: 2)
        let employeeEnhancedFirst = (firstTierEarnings * plan.enhancedRatePercent / 100).rounded(scale: 2)
        let employeeSecond = (secondTierEarnings * plan.additionalRatePercent / 100).rounded(scale: 2)
        let employeeShare = employeeFirst + employeeSecond
        let employeeEnhanced = employeeEnhancedFirst + employeeSecond
        let employeeBase = employeeFirst - employeeEnhancedFirst

        if selfEmployed {
            return PensionContribution(
                total: employeeShare * 2,
                deduction: employeeShare + employeeEnhanced,
                creditAmount: employeeBase
            )
        }
        return PensionContribution(total: employeeShare, deduction: employeeEnhanced, creditAmount: employeeBase)
    }

    /// Quebec pays a lower EI rate because QPIP covers parental benefits.
    nonisolated static func eiPremium(
        employmentIncome: Decimal,
        province: CAProvince,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        let rate = province == .quebec ? rules.ei.quebecRatePercent : rules.ei.ratePercent
        let insurable = min(max(0, employmentIncome), rules.ei.maximumInsurableEarnings)
        return (insurable * rate / 100).rounded(scale: 2)
    }

    /// Combined federal plus provincial INCOME-TAX rate on the next dollar,
    /// including the effects that scale it: the Quebec abatement shrinks the
    /// federal rate, and Ontario's surtax multiplies the provincial one.
    /// Contributions and BPA-taper effects are not included.
    nonisolated static func marginalRate(
        taxableIncome: Decimal,
        provincialTaxBeforeSurtax: Decimal,
        jurisdiction: CATaxRuleTable.Jurisdiction,
        isQuebec: Bool,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        var federal = rules.federal.brackets.last { taxableIncome > $0.lower }?.ratePercent
            ?? rules.federal.brackets.first?.ratePercent ?? 0
        if isQuebec {
            federal = federal * (100 - rules.quebecAbatementPercent) / 100
        }
        let provincial = jurisdiction.brackets.last { taxableIncome > $0.lower }?.ratePercent
            ?? jurisdiction.brackets.first?.ratePercent ?? 0
        let surtaxRate = jurisdiction.surtaxes
            .filter { provincialTaxBeforeSurtax > $0.threshold }
            .reduce(Decimal(0)) { $0 + $1.ratePercent }
        return (federal + provincial * (100 + surtaxRate) / 100).rounded(scale: 4)
    }

    // MARK: - Year resolution

    nonisolated static func requestedTaxYear(for profile: TaxProfile) -> Int {
        let leading = profile.financialYear.split(separator: "-").first ?? ""
        return Int(leading) ?? Calendar.current.component(.year, from: .now)
    }

    nonisolated static func supportedTaxYear(for profile: TaxProfile) -> Int {
        CATaxRuleTable.resolvedTaxYear(requestedTaxYear(for: profile), in: CATaxRuleTable.supportedYears)
    }

    nonisolated static func plain(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
