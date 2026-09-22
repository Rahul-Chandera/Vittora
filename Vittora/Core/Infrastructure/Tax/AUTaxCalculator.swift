import Foundation
import VittoraCore

/// Australian resident income tax, Medicare levy and CGT (M3.5).
///
/// Australia has no personal allowance in the UK sense — the tax-free threshold
/// is the first bracket — and no filing statuses. What it does have, and what is
/// modelled here:
///
/// - the **Medicare levy**, 2% of taxable income with a phase-in so crossing the
///   low-income threshold is not a cliff;
/// - the **Medicare levy surcharge**, charged only to those *without* private
///   hospital cover, on a three-tier ladder;
/// - the **Low Income Tax Offset**, a non-refundable offset which can reduce tax
///   to nil but never below it — so it is applied after tax is computed, not as
///   a deduction;
/// - the **CGT discount**, which halves a gain on an asset held over 12 months
///   before it is added to taxable income.
///
/// Resident rates only. Non-residents pay from the first dollar with no tax-free
/// threshold, which is a different table and is stated as an exclusion rather
/// than silently applying the resident one.
nonisolated struct AUTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .australia

    nonisolated static let rulesLastUpdated: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 7
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        let adv = profile.advancedInputs
        let taxYear = Self.supportedTaxYear(for: profile)
        let rules = AUTaxRuleTable.rules(for: taxYear)

        let income = max(0, profile.annualIncome)

        // Concessional super reduces assessable income, capped at the statutory
        // limit: a user who typed more than they can legally contribute must not
        // be shown tax they would not actually save.
        let concessional = min(max(0, adv.auConcessionalSuper), rules.superannuation.concessionalCap)

        // A discounted gain is added to taxable income rather than taxed apart.
        let grossGains = max(0, adv.auCapitalGains)
        let discountedGains = adv.auCapitalGainsEligibleForDiscount
            ? (grossGains * (100 - rules.capitalGains.discountPercent) / 100).rounded(scale: 2)
            : grossGains

        let deductions = profile.customDeductions.reduce(Decimal(0)) { $0 + $1.amount }
        let taxableIncome = max(0, income - concessional - deductions + discountedGains)

        let brackets = rules.brackets.apply(to: taxableIncome)
        let grossTax = brackets.reduce(Decimal(0)) { $0 + $1.taxAmount }

        // LITO is non-refundable: it cannot turn tax into a payment.
        let lito = min(grossTax, Self.lowIncomeTaxOffset(taxableIncome: taxableIncome, rules: rules))
        let taxAfterOffset = max(0, grossTax - lito)

        let medicare = Self.medicareLevy(taxableIncome: taxableIncome, rules: rules)
        let surcharge = adv.auHasPrivateHospitalCover
            ? 0
            : Self.medicareLevySurcharge(taxableIncome: taxableIncome, rules: rules)

        let finalTax = taxAfterOffset + medicare + surcharge

        var supplementary: [TaxSupplementaryLine] = []
        if medicare > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Medicare levy"), amount: medicare
            ))
        }
        if surcharge > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Medicare levy surcharge"), amount: surcharge
            ))
        }
        if lito > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Low Income Tax Offset"), amount: -lito
            ))
        }
        if discountedGains > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Net capital gain included"), amount: discountedGains
            ))
        }

        var assumptions: [String] = [
            String(localized: "Tax year runs 1 July to 30 June."),
            String(localized: "Resident tax rates applied."),
        ]
        if concessional > 0 {
            assumptions.append(String(localized: "Concessional super of \(Self.plain(concessional)) reduces assessable income."))
        }
        if adv.auCapitalGainsEligibleForDiscount, grossGains > 0 {
            assumptions.append(String(localized: "50% CGT discount applied — assumes the asset was held more than 12 months."))
        }
        if adv.auHasPrivateHospitalCover {
            assumptions.append(String(localized: "No Medicare levy surcharge, because private hospital cover is held."))
        }

        var warnings: [String] = []
        if !adv.auHasPrivateHospitalCover, surcharge > 0 {
            warnings.append(String(localized: "Medicare levy surcharge applied because no private hospital cover is recorded. Turn it on in your profile if you hold cover."))
        }
        if adv.auConcessionalSuper > rules.superannuation.concessionalCap {
            warnings.append(String(localized: "Concessional super was capped at \(Self.plain(rules.superannuation.concessionalCap)). Contributions above the cap are taxed at your marginal rate."))
        }
        if !AUTaxRuleTable.supportedYears.contains(Self.requestedTaxYear(for: profile)) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        let exclusions: [String] = [
            String(localized: "HELP, HECS and other study loan repayments are not included."),
            String(localized: "Non-resident and working holiday maker rates are not applied."),
            String(localized: "Seniors and Pensioners Tax Offset is not included."),
            String(localized: "Private health insurance rebate is not included."),
            String(localized: "Division 293 tax on high-income super contributions is not modelled."),
        ]

        return TaxEstimate(
            grossIncome: income + discountedGains,
            standardDeduction: 0,
            customDeductionsTotal: deductions + concessional,
            taxableIncome: taxableIncome,
            bracketResults: brackets,
            basicTax: taxAfterOffset,
            rebate: lito,
            surcharge: surcharge,
            cess: medicare,
            finalTax: finalTax,
            effectiveRate: (income + discountedGains) > 0
                ? (finalTax / (income + discountedGains) * 100).rounded(scale: 2)
                : 0,
            marginalRate: Self.marginalRate(taxableIncome: taxableIncome, rules: rules),
            country: .australia,
            regimeLabel: String(localized: "Resident"),
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.au.v1",
            ruleSetID: rules.ruleSetID,
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }
}

// MARK: - Components

extension AUTaxCalculator {

    /// 2% of taxable income, with a phase-in between the thresholds so that the
    /// levy rises gradually rather than appearing in full at the threshold.
    nonisolated static func medicareLevy(
        taxableIncome: Decimal,
        rules: AUTaxRuleTable.YearRules
    ) -> Decimal {
        let levy = rules.medicareLevy
        guard taxableIncome > levy.lowerThreshold else { return 0 }
        if taxableIncome >= levy.upperThreshold {
            return (taxableIncome * levy.ratePercent / 100).rounded(scale: 2)
        }
        let excess = taxableIncome - levy.lowerThreshold
        return (excess * levy.shadeInRatePercent / 100).rounded(scale: 2)
    }

    /// Charged only without private hospital cover. The applicable tier is the
    /// last one the income exceeds, so adding or splitting a tier stays a data edit.
    nonisolated static func medicareLevySurcharge(
        taxableIncome: Decimal,
        rules: AUTaxRuleTable.YearRules
    ) -> Decimal {
        guard let tier = rules.surchargeTiers.last(where: { taxableIncome > $0.threshold }) else {
            return 0
        }
        return (taxableIncome * tier.ratePercent / 100).rounded(scale: 2)
    }

    /// Full offset up to the first threshold, then two taper rates. Returned gross;
    /// the caller clamps it to the tax owed because it is non-refundable.
    nonisolated static func lowIncomeTaxOffset(
        taxableIncome: Decimal,
        rules: AUTaxRuleTable.YearRules
    ) -> Decimal {
        let lito = rules.lito
        guard taxableIncome > 0 else { return 0 }
        if taxableIncome <= lito.firstTaperThreshold { return lito.maximumOffset }
        if taxableIncome >= lito.cutOut { return 0 }

        if taxableIncome <= lito.secondTaperThreshold {
            let reduction = ((taxableIncome - lito.firstTaperThreshold) * lito.firstTaperRatePercent / 100)
            return max(0, (lito.maximumOffset - reduction).rounded(scale: 2))
        }
        let firstReduction = (lito.secondTaperThreshold - lito.firstTaperThreshold) * lito.firstTaperRatePercent / 100
        let secondReduction = (taxableIncome - lito.secondTaperThreshold) * lito.secondTaperRatePercent / 100
        return max(0, (lito.maximumOffset - firstReduction - secondReduction).rounded(scale: 2))
    }

    nonisolated static func marginalRate(
        taxableIncome: Decimal,
        rules: AUTaxRuleTable.YearRules
    ) -> Decimal {
        rules.brackets.last { taxableIncome > $0.lower }?.ratePercent
            ?? rules.brackets.first?.ratePercent
            ?? 0
    }

    // MARK: - Year resolution

    nonisolated static func requestedTaxYear(for profile: TaxProfile) -> Int {
        let leading = profile.financialYear.split(separator: "-").first ?? ""
        return Int(leading) ?? Calendar.current.component(.year, from: .now)
    }

    nonisolated static func supportedTaxYear(for profile: TaxProfile) -> Int {
        AUTaxRuleTable.resolvedTaxYear(requestedTaxYear(for: profile), in: AUTaxRuleTable.supportedYears)
    }

    nonisolated static func plain(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
