import Foundation
import VittoraCore

/// US federal income tax calculator with year-aware federal rules.
/// Supports tax years 2025 and 2026, with a legacy 2024 fallback.
struct USTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .unitedStates

    nonisolated func calculate(profile: TaxProfile) -> TaxEstimate {
        calculate(profile: profile, deductionMode: .bestAvailable)
    }

    nonisolated func calculate(profile: TaxProfile, deductionMode: USDeductionMode) -> TaxEstimate {
        let status = profile.filingStatus
        let gross = profile.annualIncome
        let adv = profile.advancedInputs
        let taxYear = Self.supportedTaxYear(for: profile)
        let yearRules = USTaxRuleTable.rules(for: taxYear)
        let ruleSetID = "US_FEDERAL_TY\(taxYear)"
        let rulesLastUpdated = Self.rulesLastUpdated

        var standardDeduction = Self.standardDeduction(for: status, taxYear: taxYear)
        if let age = ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear), age >= 65 {
            standardDeduction += yearRules.age65AdditionalStandardDeduction
        }

        let itemizedDeductions = profile.customDeductions.reduce(Decimal(0)) { $0 + $1.amount }
        let deductionSelection = selectDeduction(
            standardDeduction: standardDeduction,
            itemizedDeductions: itemizedDeductions,
            deductionMode: deductionMode
        )

        let ordinaryGross = gross + adv.usShortTermCapitalGains
        let taxableOrdinary = max(0, ordinaryGross - deductionSelection.appliedDeduction)

        let slabs = Self.brackets(for: status, taxYear: taxYear)
        let bracketResults = slabs.apply(to: taxableOrdinary)

        let ordinaryFederalTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        let preferentialIncome = adv.usLongTermCapitalGains + adv.usQualifiedDividends
        let preferentialTax = Self.preferentialCapitalGainsTax(
            amount: preferentialIncome,
            ordinaryTaxable: taxableOrdinary,
            status: status,
            taxYear: taxYear
        )

        let magi = ordinaryGross + adv.usLongTermCapitalGains + adv.usQualifiedDividends + adv.usOtherInvestmentIncome
        let netInvestmentIncome = adv.usLongTermCapitalGains + adv.usQualifiedDividends + adv.usShortTermCapitalGains + adv.usOtherInvestmentIncome
        let niit = Self.netInvestmentIncomeTax(
            magi: magi,
            netInvestmentIncome: netInvestmentIncome,
            status: status,
            taxYear: taxYear
        )

        let wagesForPayroll = max(0, gross)
        let payroll = Self.payrollTaxes(wages: wagesForPayroll, status: status, taxYear: taxYear)

        let incomeTaxTotal = (ordinaryFederalTax + preferentialTax + niit).rounded(scale: 2)
        let totalDenominator = max(ordinaryGross + preferentialIncome, 1)
        let effectiveRate = (incomeTaxTotal / totalDenominator).rounded(scale: 4)
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        var supplementary: [TaxSupplementaryLine] = payroll.lines
        supplementary += USContributionHeadroomEngine.supplementaryHeadroomLines(
            profile: profile,
            taxYear: taxYear
        )

        var assumptions: [String] = [
            String(localized: "Annual income treated as wages for Social Security and Medicare estimates unless you adjust advanced inputs.")
        ]
        if preferentialIncome > 0 {
            assumptions.append(String(localized: "Long-term gains and qualified dividends are modeled with status/year 0/15/20% bracket stacking against ordinary taxable income."))
        }
        if netInvestmentIncome > 0 {
            assumptions.append(String(localized: "Net Investment Income Tax uses a simplified MAGI model."))
        }

        var warnings: [String] = []
        if profile.dateOfBirth != nil, ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear).map({ $0 >= 65 }) == true {
            warnings.append(String(localized: "OBBBA additional standard deduction for age 65+ is modeled without income phase-outs."))
        }

        let exclusions = [
            String(localized: "Alternative Minimum Tax (AMT) is not calculated."),
            TaxDisclaimer.usFederalEstimateLabel,
            String(localized: "Payroll taxes are shown separately and are not included in the federal income tax total.")
        ]

        return TaxEstimate(
            grossIncome: gross,
            standardDeduction: deductionSelection.standardDeductionPortion,
            customDeductionsTotal: deductionSelection.customDeductionsPortion,
            taxableIncome: taxableOrdinary,
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
            ruleSetID: ruleSetID,
            rulesLastUpdated: rulesLastUpdated
        )
    }

    nonisolated private static let rulesLastUpdated: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 18)) ?? .now
    }()

    nonisolated private func ageAtEndOfTaxYear(dateOfBirth: Date?, taxYear: Int) -> Int? {
        guard let dob = dateOfBirth else { return nil }
        guard let end = Calendar.current.date(from: DateComponents(year: taxYear, month: 12, day: 31)) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: end).year
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

    nonisolated static func supportedTaxYear(for profile: TaxProfile) -> Int {
        parsedTaxYear(from: profile.financialYear) ?? USTaxRuleTable.latestTaxYear
    }

    nonisolated private static func parsedTaxYear(from financialYear: String) -> Int? {
        Int(financialYear.prefix(4))
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
