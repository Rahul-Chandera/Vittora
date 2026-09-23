import Foundation
import VittoraCore

/// Canadian federal and provincial income tax, CPP/EI and capital gains (M3.5).
///
/// Canada is the first two-level calculator here: the US one is federal-only, so
/// there was no existing pattern for sub-national tax. Provincial tax is a second
/// full bracket table, not a surcharge on the federal one — which is why a
/// federal-only estimate understates a Canadian's bill by roughly a third and was
/// rejected as an option.
///
/// The order matters and is explicit below:
///
/// 1. deductions (RRSP) reduce income;
/// 2. federal and provincial brackets are applied to the *same* taxable income;
/// 3. each level's basic personal amount is a **non-refundable credit at that
///    level's lowest rate**, not a deduction — a credit of 14.5% of the federal
///    BPA is worth far less than deducting it, and treating it as a deduction
///    would understate tax at every income above the lowest bracket;
/// 4. Ontario and PEI charge a surtax on their own tax, after credits;
/// 5. Quebec reduces basic federal tax by the 16.5% abatement, because Quebec
///    administers programmes Ottawa funds elsewhere. Missing it overstates a
///    Quebec bill badly.
nonisolated struct CATaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .canada

    nonisolated static let rulesLastUpdated: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        let adv = profile.advancedInputs
        let taxYear = Self.supportedTaxYear(for: profile)
        let rules = CATaxRuleTable.rules(for: taxYear)
        let province = adv.caProvince

        let employmentIncome = max(0, profile.annualIncome)

        // Half of a capital gain is included in income.
        let taxableCapitalGain = (max(0, adv.caCapitalGains)
            * rules.capitalGainsInclusionPercent / 100).rounded(scale: 2)

        let rrsp = max(0, adv.caRRSPContributions)
        let otherDeductions = profile.customDeductions.reduce(Decimal(0)) { $0 + $1.amount }
        let deductions = rrsp + otherDeductions

        let taxableIncome = max(0, employmentIncome + taxableCapitalGain - deductions)

        // MARK: Federal

        let federalBPA = Self.federalBasicPersonalAmount(taxableIncome: taxableIncome, rules: rules)
        let federalBrackets = rules.federal.brackets.apply(to: taxableIncome)
        let federalGross = federalBrackets.reduce(Decimal(0)) { $0 + $1.taxAmount }
        let federalCredit = (federalBPA * rules.federal.creditRatePercent / 100).rounded(scale: 2)
        var federalTax = max(0, federalGross - federalCredit)

        // Quebec's abatement applies to basic federal tax.
        var abatement = Decimal(0)
        if province == .quebec {
            abatement = (federalTax * rules.quebecAbatementPercent / 100).rounded(scale: 2)
            federalTax = max(0, federalTax - abatement)
        }

        // MARK: Provincial

        let jurisdiction = rules.provinces[province] ?? rules.federal
        let provincialBrackets = jurisdiction.brackets.apply(to: taxableIncome)
        let provincialGross = provincialBrackets.reduce(Decimal(0)) { $0 + $1.taxAmount }
        let provincialCredit = (jurisdiction.basicPersonalAmount
            * jurisdiction.creditRatePercent / 100).rounded(scale: 2)
        let provincialBeforeSurtax = max(0, provincialGross - provincialCredit)
        let surtax = Self.surtax(on: provincialBeforeSurtax, jurisdiction: jurisdiction)
        let provincialTax = provincialBeforeSurtax + surtax

        // MARK: Payroll

        let cpp = Self.cppContribution(employmentIncome: employmentIncome, rules: rules)
        let ei = Self.eiPremium(employmentIncome: employmentIncome, province: province, rules: rules)

        let finalTax = federalTax + provincialTax + cpp + ei
        let grossIncome = employmentIncome + taxableCapitalGain

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
        if cpp > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: province == .quebec
                    ? String(localized: "QPP contribution")
                    : String(localized: "CPP contribution"),
                amount: cpp
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
        ]
        if taxableCapitalGain > 0 {
            assumptions.append(String(localized: "Half of your capital gains is included in income."))
        }
        if abatement > 0 {
            assumptions.append(String(localized: "Quebec's 16.5% federal abatement applied."))
        }
        if federalBPA < rules.federal.basicPersonalAmount {
            assumptions.append(String(localized: "Federal basic personal amount reduced to \(Self.plain(federalBPA)) because of income level."))
        }

        var warnings: [String] = [
            String(localized: "Provincial and territorial figures are being verified. Treat provincial amounts as indicative until confirmed."),
        ]
        if !CATaxRuleTable.supportedYears.contains(Self.requestedTaxYear(for: profile)) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        let exclusions: [String] = [
            String(localized: "Provincial health premiums and levies are not included."),
            String(localized: "Quebec Parental Insurance Plan premiums are not included."),
            String(localized: "Canada Employment Amount and other non-refundable credits are not included."),
            String(localized: "GST/HST credit, Canada Child Benefit and other refundable credits are not included."),
            String(localized: "Dividend gross-up and dividend tax credits are not modelled."),
        ]

        return TaxEstimate(
            grossIncome: grossIncome,
            standardDeduction: federalBPA,
            customDeductionsTotal: deductions,
            taxableIncome: taxableIncome,
            bracketResults: federalBrackets,
            basicTax: federalTax,
            rebate: federalCredit + provincialCredit,
            surcharge: provincialTax,
            cess: cpp + ei,
            finalTax: finalTax,
            effectiveRate: grossIncome > 0 ? (finalTax / grossIncome).rounded(scale: 4) : 0,
            marginalRate: Self.marginalRate(taxableIncome: taxableIncome, jurisdiction: jurisdiction, rules: rules),
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

    /// The federal BPA is clawed back across the top two brackets, from its
    /// maximum down to a floor — not to zero, unlike the UK's allowance.
    nonisolated static func federalBasicPersonalAmount(
        taxableIncome: Decimal,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        let maximum = rules.federal.basicPersonalAmount
        let minimum = rules.federalBasicPersonalAmountMinimum
        if taxableIncome <= rules.federalBPATaperStart { return maximum }
        if taxableIncome >= rules.federalBPATaperEnd { return minimum }

        let span = rules.federalBPATaperEnd - rules.federalBPATaperStart
        guard span > 0 else { return maximum }
        let progress = (taxableIncome - rules.federalBPATaperStart) / span
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

    /// Base contribution on earnings between the exemption and the YMPE, plus
    /// CPP2 on the band from YMPE to YAMPE. Quebec's QPP differs slightly in rate
    /// but is modelled on the same mechanics; the label says QPP there.
    nonisolated static func cppContribution(
        employmentIncome: Decimal,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        let cpp = rules.cpp
        guard employmentIncome > cpp.basicExemption else { return 0 }

        let pensionable = min(employmentIncome, cpp.maximumPensionableEarnings) - cpp.basicExemption
        var total = (max(0, pensionable) * cpp.ratePercent / 100).rounded(scale: 2)

        if employmentIncome > cpp.maximumPensionableEarnings {
            let second = min(employmentIncome, cpp.additionalMaximumPensionableEarnings)
                - cpp.maximumPensionableEarnings
            total += (max(0, second) * cpp.additionalRatePercent / 100).rounded(scale: 2)
        }
        return total
    }

    /// Quebec pays a lower EI rate because QPIP covers parental benefits there.
    nonisolated static func eiPremium(
        employmentIncome: Decimal,
        province: CAProvince,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        let rate = province == .quebec ? rules.ei.quebecRatePercent : rules.ei.ratePercent
        let insurable = min(max(0, employmentIncome), rules.ei.maximumInsurableEarnings)
        return (insurable * rate / 100).rounded(scale: 2)
    }

    /// Combined federal plus provincial rate on the next dollar — the number a
    /// Canadian actually plans against, rather than either level alone.
    nonisolated static func marginalRate(
        taxableIncome: Decimal,
        jurisdiction: CATaxRuleTable.Jurisdiction,
        rules: CATaxRuleTable.YearRules
    ) -> Decimal {
        let federal = rules.federal.brackets.last { taxableIncome > $0.lower }?.ratePercent
            ?? rules.federal.brackets.first?.ratePercent ?? 0
        let provincial = jurisdiction.brackets.last { taxableIncome > $0.lower }?.ratePercent
            ?? jurisdiction.brackets.first?.ratePercent ?? 0
        return federal + provincial
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
