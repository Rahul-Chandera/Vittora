import Foundation

/// US federal income tax calculator with year-aware federal rules.
/// Supports tax years 2025 and 2026, with a legacy 2024 fallback.
struct USTaxCalculator: TaxCalculatorProtocol {
    let country: TaxCountry = .unitedStates

    func calculate(profile: TaxProfile) -> TaxEstimate {
        calculate(profile: profile, deductionMode: .bestAvailable)
    }

    func calculate(profile: TaxProfile, deductionMode: USDeductionMode) -> TaxEstimate {
        let status = profile.filingStatus
        let gross = profile.annualIncome
        let adv = profile.advancedInputs
        let taxYear = Self.supportedTaxYear(for: profile)
        let ruleSetID = "US_FEDERAL_TY\(taxYear)"
        let rulesLastUpdated = Self.rulesLastUpdated

        var standardDeduction = Self.standardDeduction(for: status, taxYear: taxYear)
        if let age = ageAtEndOfTaxYear(dateOfBirth: profile.dateOfBirth, taxYear: taxYear), age >= 65 {
            standardDeduction += 6_000
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
            status: status
        )

        let wagesForPayroll = max(0, gross)
        let payroll = Self.payrollTaxes(wages: wagesForPayroll, status: status, taxYear: taxYear)

        let incomeTaxTotal = (ordinaryFederalTax + preferentialTax + niit).rounded(scale: 2)
        let totalDenominator = max(ordinaryGross + preferentialIncome, 1)
        let effectiveRate = (incomeTaxTotal / totalDenominator).rounded(scale: 4)
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        var supplementary: [TaxSupplementaryLine] = payroll.lines
        supplementary += Self.contributionAdvisoryLines(taxYear: taxYear)

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
            String(localized: "State and local taxes are not included."),
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

    private static let rulesLastUpdated: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 18)) ?? .now
    }()

    private func ageAtEndOfTaxYear(dateOfBirth: Date?, taxYear: Int) -> Int? {
        guard let dob = dateOfBirth else { return nil }
        guard let end = Calendar.current.date(from: DateComponents(year: taxYear, month: 12, day: 31)) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: end).year
    }

    private struct PayrollBreakdown {
        let lines: [TaxSupplementaryLine]
    }

    private static func payrollTaxes(wages: Decimal, status: USFilingStatus, taxYear: Int) -> PayrollBreakdown {
        let ssWageBase: Decimal = taxYear >= 2026 ? 184_500 : 176_100
        let ss = (min(wages, ssWageBase) * (Decimal(string: "0.062") ?? 0)).rounded(scale: 2)
        let medicare = (wages * (Decimal(string: "0.0145") ?? 0)).rounded(scale: 2)
        let addMedThreshold: Decimal
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            addMedThreshold = 250_000
        case .marriedFilingSeparately:
            addMedThreshold = 125_000
        default:
            addMedThreshold = 200_000
        }
        let additionalMedicare = (max(0, wages - addMedThreshold) * (Decimal(string: "0.009") ?? 0)).rounded(scale: 2)
        let lines = [
            TaxSupplementaryLine(title: String(localized: "Social Security (employee)"), amount: ss),
            TaxSupplementaryLine(title: String(localized: "Medicare (employee)"), amount: medicare),
            TaxSupplementaryLine(title: String(localized: "Additional Medicare Tax"), amount: additionalMedicare)
        ]
        return PayrollBreakdown(lines: lines)
    }

    private static func netInvestmentIncomeTax(magi: Decimal, netInvestmentIncome: Decimal, status: USFilingStatus) -> Decimal {
        guard netInvestmentIncome > 0 else { return 0 }
        let threshold: Decimal
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            threshold = 250_000
        case .marriedFilingSeparately:
            threshold = 125_000
        default:
            threshold = 200_000
        }
        guard magi > threshold else { return 0 }
        let base = min(netInvestmentIncome, magi - threshold)
        return (max(0, base) * (Decimal(string: "0.038") ?? 0)).rounded(scale: 2)
    }

    private static func preferentialCapitalGainsTax(
        amount: Decimal,
        ordinaryTaxable: Decimal,
        status: USFilingStatus,
        taxYear: Int
    ) -> Decimal {
        guard amount > 0 else { return 0 }
        let thresholds = preferentialThresholds(status: status, taxYear: taxYear)

        let zeroRateCapacity = max(0, thresholds.zeroRateUpperBound - ordinaryTaxable)
        let zeroRatePortion = min(amount, zeroRateCapacity)

        let amountRemainingAfterZeroRate = amount - zeroRatePortion
        let fifteenRateStart = max(ordinaryTaxable, thresholds.zeroRateUpperBound)
        let fifteenRateCapacity = max(0, thresholds.fifteenRateUpperBound - fifteenRateStart)
        let fifteenRatePortion = min(amountRemainingAfterZeroRate, fifteenRateCapacity)

        let twentyRatePortion = max(0, amountRemainingAfterZeroRate - fifteenRatePortion)

        let fifteenRateTax = (fifteenRatePortion * (Decimal(string: "0.15") ?? 0))
        let twentyRateTax = (twentyRatePortion * (Decimal(string: "0.20") ?? 0))
        return (fifteenRateTax + twentyRateTax).rounded(scale: 2)
    }

    private struct PreferentialThresholds {
        let zeroRateUpperBound: Decimal
        let fifteenRateUpperBound: Decimal
    }

    private static func preferentialThresholds(status: USFilingStatus, taxYear: Int) -> PreferentialThresholds {
        switch supportedTaxYearValue(from: taxYear) {
        case .ty2024:
            return preferentialThresholds2024(status: status)
        case .ty2025:
            return preferentialThresholds2025(status: status)
        case .ty2026:
            return preferentialThresholds2026(status: status)
        }
    }

    private static func preferentialThresholds2024(status: USFilingStatus) -> PreferentialThresholds {
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            PreferentialThresholds(zeroRateUpperBound: 94_050, fifteenRateUpperBound: 583_750)
        case .marriedFilingSeparately:
            PreferentialThresholds(zeroRateUpperBound: 47_025, fifteenRateUpperBound: 291_850)
        case .headOfHousehold:
            PreferentialThresholds(zeroRateUpperBound: 63_000, fifteenRateUpperBound: 551_350)
        case .single:
            PreferentialThresholds(zeroRateUpperBound: 47_025, fifteenRateUpperBound: 518_900)
        }
    }

    private static func preferentialThresholds2025(status: USFilingStatus) -> PreferentialThresholds {
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            PreferentialThresholds(zeroRateUpperBound: 96_700, fifteenRateUpperBound: 600_050)
        case .marriedFilingSeparately:
            PreferentialThresholds(zeroRateUpperBound: 48_350, fifteenRateUpperBound: 300_000)
        case .headOfHousehold:
            PreferentialThresholds(zeroRateUpperBound: 64_750, fifteenRateUpperBound: 566_700)
        case .single:
            PreferentialThresholds(zeroRateUpperBound: 48_350, fifteenRateUpperBound: 533_400)
        }
    }

    private static func preferentialThresholds2026(status: USFilingStatus) -> PreferentialThresholds {
        // Uses current app rule assumptions for TY2026.
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            PreferentialThresholds(zeroRateUpperBound: 100_000, fifteenRateUpperBound: 612_000)
        case .marriedFilingSeparately:
            PreferentialThresholds(zeroRateUpperBound: 50_000, fifteenRateUpperBound: 306_000)
        case .headOfHousehold:
            PreferentialThresholds(zeroRateUpperBound: 67_000, fifteenRateUpperBound: 578_000)
        case .single:
            PreferentialThresholds(zeroRateUpperBound: 50_000, fifteenRateUpperBound: 545_000)
        }
    }

    private static func contributionAdvisoryLines(taxYear: Int) -> [TaxSupplementaryLine] {
        if taxYear >= 2026 {
            return [
                TaxSupplementaryLine(title: String(localized: "401(k) elective deferral limit (advisory)"), amount: 24_500),
                TaxSupplementaryLine(title: String(localized: "IRA contribution limit (advisory)"), amount: 7_500),
                TaxSupplementaryLine(title: String(localized: "HSA family contribution limit (advisory)"), amount: 8_750)
            ]
        }
        return [
            TaxSupplementaryLine(title: String(localized: "401(k) elective deferral limit (advisory)"), amount: 23_500),
            TaxSupplementaryLine(title: String(localized: "IRA contribution limit (advisory)"), amount: 7_000),
            TaxSupplementaryLine(title: String(localized: "HSA family contribution limit (advisory)"), amount: 8_550)
        ]
    }

    private func selectDeduction(
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

    private func regimeLabel(for status: USFilingStatus, deductionMode: USDeductionMode) -> String {
        switch deductionMode {
        case .bestAvailable:
            status.displayName
        case .standardOnly:
            String(localized: "\(status.displayName) · Standard Deduction")
        case .itemizedOnly:
            String(localized: "\(status.displayName) · Itemized Deductions")
        }
    }

    private enum TaxYear: Int {
        case ty2024 = 2024
        case ty2025 = 2025
        case ty2026 = 2026
    }

    private struct TaxRules {
        let standardDeduction: Decimal
        let brackets: [TaxSlab]
    }

    static func standardDeduction(for status: USFilingStatus, taxYear: Int) -> Decimal {
        rules(for: status, taxYear: taxYear).standardDeduction
    }

    static func brackets(for status: USFilingStatus, taxYear: Int) -> [TaxSlab] {
        rules(for: status, taxYear: taxYear).brackets
    }

    private static func rules(for status: USFilingStatus, taxYear: Int) -> TaxRules {
        switch supportedTaxYearValue(from: taxYear) {
        case .ty2024:
            return legacy2024Rules(for: status)
        case .ty2025:
            return taxYear2025Rules(for: status)
        case .ty2026:
            return taxYear2026Rules(for: status)
        }
    }

    private static func supportedTaxYear(for profile: TaxProfile) -> Int {
        parsedTaxYear(from: profile.financialYear) ?? TaxYear.ty2026.rawValue
    }

    private static func supportedTaxYearValue(from taxYear: Int) -> TaxYear {
        switch taxYear {
        case ...TaxYear.ty2024.rawValue:
            .ty2024
        case TaxYear.ty2025.rawValue:
            .ty2025
        default:
            .ty2026
        }
    }

    private static func parsedTaxYear(from financialYear: String) -> Int? {
        Int(financialYear.prefix(4))
    }

    private static func legacy2024Rules(for status: USFilingStatus) -> TaxRules {
        switch status {
        case .single:
            return TaxRules(
                standardDeduction: 14_600,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                    TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,600 – $47,150"),
                    TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,150 – $100,525"),
                    TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,525 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,950 – $243,725"),
                    TaxSlab(lower: 243_725, upper: 609_350, ratePercent: 35, label: "$243,725 – $609,350"),
                    TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
                ]
            )
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            return TaxRules(
                standardDeduction: 29_200,
                brackets: [
                    TaxSlab(lower: 0,       upper: 23_200,  ratePercent: 10, label: "$0 – $23,200"),
                    TaxSlab(lower: 23_200,  upper: 94_300,  ratePercent: 12, label: "$23,200 – $94,300"),
                    TaxSlab(lower: 94_300,  upper: 201_050, ratePercent: 22, label: "$94,300 – $201,050"),
                    TaxSlab(lower: 201_050, upper: 383_900, ratePercent: 24, label: "$201,050 – $383,900"),
                    TaxSlab(lower: 383_900, upper: 487_450, ratePercent: 32, label: "$383,900 – $487,450"),
                    TaxSlab(lower: 487_450, upper: 731_200, ratePercent: 35, label: "$487,450 – $731,200"),
                    TaxSlab(lower: 731_200, upper: nil,     ratePercent: 37, label: "Over $731,200"),
                ]
            )
        case .marriedFilingSeparately:
            return TaxRules(
                standardDeduction: 14_600,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_600,  ratePercent: 10, label: "$0 – $11,600"),
                    TaxSlab(lower: 11_600,  upper: 47_150,  ratePercent: 12, label: "$11,600 – $47,150"),
                    TaxSlab(lower: 47_150,  upper: 100_525, ratePercent: 22, label: "$47,150 – $100,525"),
                    TaxSlab(lower: 100_525, upper: 191_950, ratePercent: 24, label: "$100,525 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_725, ratePercent: 32, label: "$191,950 – $243,725"),
                    TaxSlab(lower: 243_725, upper: 365_600, ratePercent: 35, label: "$243,725 – $365,600"),
                    TaxSlab(lower: 365_600, upper: nil,     ratePercent: 37, label: "Over $365,600"),
                ]
            )
        case .headOfHousehold:
            return TaxRules(
                standardDeduction: 21_900,
                brackets: [
                    TaxSlab(lower: 0,       upper: 16_550,  ratePercent: 10, label: "$0 – $16,550"),
                    TaxSlab(lower: 16_550,  upper: 63_100,  ratePercent: 12, label: "$16,550 – $63,100"),
                    TaxSlab(lower: 63_100,  upper: 100_500, ratePercent: 22, label: "$63,100 – $100,500"),
                    TaxSlab(lower: 100_500, upper: 191_950, ratePercent: 24, label: "$100,500 – $191,950"),
                    TaxSlab(lower: 191_950, upper: 243_700, ratePercent: 32, label: "$191,950 – $243,700"),
                    TaxSlab(lower: 243_700, upper: 609_350, ratePercent: 35, label: "$243,700 – $609,350"),
                    TaxSlab(lower: 609_350, upper: nil,     ratePercent: 37, label: "Over $609,350"),
                ]
            )
        }
    }

    private static func taxYear2025Rules(for status: USFilingStatus) -> TaxRules {
        switch status {
        case .single:
            return TaxRules(
                standardDeduction: 15_750,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_925,  ratePercent: 10, label: "$0 – $11,925"),
                    TaxSlab(lower: 11_925,  upper: 48_475,  ratePercent: 12, label: "$11,925 – $48,475"),
                    TaxSlab(lower: 48_475,  upper: 103_350, ratePercent: 22, label: "$48,475 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_525, ratePercent: 32, label: "$197,300 – $250,525"),
                    TaxSlab(lower: 250_525, upper: 626_350, ratePercent: 35, label: "$250,525 – $626,350"),
                    TaxSlab(lower: 626_350, upper: nil,     ratePercent: 37, label: "Over $626,350"),
                ]
            )
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            return TaxRules(
                standardDeduction: 31_500,
                brackets: [
                    TaxSlab(lower: 0,       upper: 23_850,  ratePercent: 10, label: "$0 – $23,850"),
                    TaxSlab(lower: 23_850,  upper: 96_950,  ratePercent: 12, label: "$23,850 – $96,950"),
                    TaxSlab(lower: 96_950,  upper: 206_700, ratePercent: 22, label: "$96,950 – $206,700"),
                    TaxSlab(lower: 206_700, upper: 394_600, ratePercent: 24, label: "$206,700 – $394,600"),
                    TaxSlab(lower: 394_600, upper: 501_050, ratePercent: 32, label: "$394,600 – $501,050"),
                    TaxSlab(lower: 501_050, upper: 751_600, ratePercent: 35, label: "$501,050 – $751,600"),
                    TaxSlab(lower: 751_600, upper: nil,     ratePercent: 37, label: "Over $751,600"),
                ]
            )
        case .marriedFilingSeparately:
            return TaxRules(
                standardDeduction: 15_750,
                brackets: [
                    TaxSlab(lower: 0,       upper: 11_925,  ratePercent: 10, label: "$0 – $11,925"),
                    TaxSlab(lower: 11_925,  upper: 48_475,  ratePercent: 12, label: "$11,925 – $48,475"),
                    TaxSlab(lower: 48_475,  upper: 103_350, ratePercent: 22, label: "$48,475 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_525, ratePercent: 32, label: "$197,300 – $250,525"),
                    TaxSlab(lower: 250_525, upper: 375_800, ratePercent: 35, label: "$250,525 – $375,800"),
                    TaxSlab(lower: 375_800, upper: nil,     ratePercent: 37, label: "Over $375,800"),
                ]
            )
        case .headOfHousehold:
            return TaxRules(
                standardDeduction: 23_625,
                brackets: [
                    TaxSlab(lower: 0,       upper: 17_000,  ratePercent: 10, label: "$0 – $17,000"),
                    TaxSlab(lower: 17_000,  upper: 64_850,  ratePercent: 12, label: "$17,000 – $64,850"),
                    TaxSlab(lower: 64_850,  upper: 103_350, ratePercent: 22, label: "$64,850 – $103,350"),
                    TaxSlab(lower: 103_350, upper: 197_300, ratePercent: 24, label: "$103,350 – $197,300"),
                    TaxSlab(lower: 197_300, upper: 250_500, ratePercent: 32, label: "$197,300 – $250,500"),
                    TaxSlab(lower: 250_500, upper: 626_350, ratePercent: 35, label: "$250,500 – $626,350"),
                    TaxSlab(lower: 626_350, upper: nil,     ratePercent: 37, label: "Over $626,350"),
                ]
            )
        }
    }

    private static func taxYear2026Rules(for status: USFilingStatus) -> TaxRules {
        switch status {
        case .single:
            return TaxRules(
                standardDeduction: 16_100,
                brackets: [
                    TaxSlab(lower: 0,       upper: 12_400,  ratePercent: 10, label: "$0 – $12,400"),
                    TaxSlab(lower: 12_400,  upper: 50_400,  ratePercent: 12, label: "$12,400 – $50,400"),
                    TaxSlab(lower: 50_400,  upper: 105_700, ratePercent: 22, label: "$50,400 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_775, ratePercent: 24, label: "$105,700 – $201,775"),
                    TaxSlab(lower: 201_775, upper: 256_225, ratePercent: 32, label: "$201,775 – $256,225"),
                    TaxSlab(lower: 256_225, upper: 640_600, ratePercent: 35, label: "$256,225 – $640,600"),
                    TaxSlab(lower: 640_600, upper: nil,     ratePercent: 37, label: "Over $640,600"),
                ]
            )
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            return TaxRules(
                standardDeduction: 32_200,
                brackets: [
                    TaxSlab(lower: 0,       upper: 24_800,  ratePercent: 10, label: "$0 – $24,800"),
                    TaxSlab(lower: 24_800,  upper: 100_800, ratePercent: 12, label: "$24,800 – $100,800"),
                    TaxSlab(lower: 100_800, upper: 211_400, ratePercent: 22, label: "$100,800 – $211,400"),
                    TaxSlab(lower: 211_400, upper: 403_550, ratePercent: 24, label: "$211,400 – $403,550"),
                    TaxSlab(lower: 403_550, upper: 512_450, ratePercent: 32, label: "$403,550 – $512,450"),
                    TaxSlab(lower: 512_450, upper: 768_700, ratePercent: 35, label: "$512,450 – $768,700"),
                    TaxSlab(lower: 768_700, upper: nil,     ratePercent: 37, label: "Over $768,700"),
                ]
            )
        case .marriedFilingSeparately:
            return TaxRules(
                standardDeduction: 16_100,
                brackets: [
                    TaxSlab(lower: 0,       upper: 12_400,  ratePercent: 10, label: "$0 – $12,400"),
                    TaxSlab(lower: 12_400,  upper: 50_400,  ratePercent: 12, label: "$12,400 – $50,400"),
                    TaxSlab(lower: 50_400,  upper: 105_700, ratePercent: 22, label: "$50,400 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_775, ratePercent: 24, label: "$105,700 – $201,775"),
                    TaxSlab(lower: 201_775, upper: 256_225, ratePercent: 32, label: "$201,775 – $256,225"),
                    TaxSlab(lower: 256_225, upper: 384_350, ratePercent: 35, label: "$256,225 – $384,350"),
                    TaxSlab(lower: 384_350, upper: nil,     ratePercent: 37, label: "Over $384,350"),
                ]
            )
        case .headOfHousehold:
            return TaxRules(
                standardDeduction: 24_150,
                brackets: [
                    TaxSlab(lower: 0,       upper: 17_700,  ratePercent: 10, label: "$0 – $17,700"),
                    TaxSlab(lower: 17_700,  upper: 67_450,  ratePercent: 12, label: "$17,700 – $67,450"),
                    TaxSlab(lower: 67_450,  upper: 105_700, ratePercent: 22, label: "$67,450 – $105,700"),
                    TaxSlab(lower: 105_700, upper: 201_750, ratePercent: 24, label: "$105,700 – $201,750"),
                    TaxSlab(lower: 201_750, upper: 256_200, ratePercent: 32, label: "$201,750 – $256,200"),
                    TaxSlab(lower: 256_200, upper: 640_600, ratePercent: 35, label: "$256,200 – $640,600"),
                    TaxSlab(lower: 640_600, upper: nil,     ratePercent: 37, label: "Over $640,600"),
                ]
            )
        }
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
