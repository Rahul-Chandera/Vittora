import Foundation
import VittoraCore

/// UK income tax, National Insurance and capital gains (M3.5).
///
/// The UK taxes three streams in a fixed order — non-savings, then savings, then
/// dividends — and each later stream is taxed at the band the earlier ones have
/// already used up. Getting that order wrong changes the answer, so it is explicit
/// below rather than implied.
///
/// Two things that are easy to get wrong and are handled deliberately:
///
/// 1. **Scottish rates apply to one stream only.** A Scottish taxpayer pays Scottish
///    rates on non-savings, non-dividend income, and UK-wide rates on savings and
///    dividends. Applying Scottish rates to all three would overstate the bill.
/// 2. **The personal allowance tapers.** Above £100,000 it falls by £1 for every £2
///    of income and is gone at £125,140, which creates the well-known 60% effective
///    band. It is computed from ADJUSTED NET income — total income less the
///    reliefs entered (net-pay pension, Gift Aid) — not from earnings alone.
nonisolated struct UKTaxCalculator: TaxCalculatorProtocol {
    nonisolated let country: TaxCountry = .unitedKingdom

    /// The date the figures in `UKTaxRuleTable` were last checked against HMRC.
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
        let rules = UKTaxRuleTable.rules(for: taxYear)
        let isScottish = adv.ukIsScottishTaxpayer

        let earnedIncome = max(0, profile.annualIncome)
        let savingsIncome = max(0, adv.ukSavingsIncome)
        let dividendIncome = max(0, adv.ukDividendIncome)
        let totalIncome = earnedIncome + savingsIncome + dividendIncome

        // Reliefs the user entered (net-pay pension contributions, Gift Aid,
        // allowable expenses), treated as a net-pay deduction: they reduce
        // adjusted net income — and so restore tapered allowance — as well as
        // taxable income. Negative entries are ignored rather than adding tax.
        let customDeductions = profile.customDeductions.reduce(Decimal(0)) { $0 + max(0, $1.amount) }
        let reliefApplied = min(customDeductions, totalIncome)
        let incomeAfterRelief = totalIncome - reliefApplied

        // Taper on adjusted net income, not gross (review UK-03).
        let personalAllowance = Self.personalAllowance(totalIncome: incomeAfterRelief, rules: rules)

        // Relief comes off earnings, then savings, then dividends — so a
        // taxpayer with no earnings still gets it.
        let reliefOnEarnings = min(reliefApplied, earnedIncome)
        let reliefOnSavings = min(reliefApplied - reliefOnEarnings, savingsIncome)
        let reliefOnDividends = reliefApplied - reliefOnEarnings - reliefOnSavings
        let netEarnings = earnedIncome - reliefOnEarnings
        let netSavings = savingsIncome - reliefOnSavings
        let netDividends = max(0, dividendIncome - reliefOnDividends)

        // The allowance is set against non-savings income first because that is the
        // allocation that leaves the taxpayer best off, and it is what HMRC applies
        // by default.
        let allowanceUsedAgainstEarnings = min(personalAllowance, netEarnings)
        let taxableEarnings = netEarnings - allowanceUsedAgainstEarnings
        let allowanceRemaining = max(0, personalAllowance - allowanceUsedAgainstEarnings)

        let region = rules.regionBands(isScottishTaxpayer: isScottish)
        let earningsBrackets = region.bands.apply(to: taxableEarnings)
        let earningsTax = earningsBrackets.reduce(Decimal(0)) { $0 + $1.taxAmount }

        // MARK: Savings

        let allowanceUsedAgainstSavings = min(allowanceRemaining, netSavings)
        let taxableSavings = max(0, netSavings - allowanceUsedAgainstSavings)
        let savings = Self.savingsTax(
            taxableSavings: taxableSavings,
            taxableEarnings: taxableEarnings,
            incomeAfterRelief: incomeAfterRelief,
            rules: rules,
            region: region
        )
        let allowanceAfterSavings = max(0, allowanceRemaining - allowanceUsedAgainstSavings)

        // MARK: Dividends

        let allowanceUsedAgainstDividends = min(allowanceAfterSavings, netDividends)
        let taxableDividends = max(0, netDividends - allowanceUsedAgainstDividends)
        let dividends = Self.dividendTax(
            taxableDividends: taxableDividends,
            otherTaxableIncome: taxableEarnings + taxableSavings,
            rules: rules
        )

        // MARK: National Insurance

        // NI is charged on earnings, never on savings or dividends, and it ignores
        // the personal allowance — it has its own threshold that merely happens to
        // match it this year.
        //
        // Employees stop paying Class 1 at State Pension age; Class 4 stops from
        // the tax year after it is reached. Earnings before that date still pay.
        let isSelfEmployed = profile.incomeSourceType == .selfEmployed
        let niShare = Self.niLiableShareOfYear(
            dateOfBirth: profile.dateOfBirth,
            taxYear: taxYear,
            isSelfEmployed: isSelfEmployed
        )
        let nationalInsurance = Self.nationalInsurance(
            earnings: (earnedIncome * niShare).rounded(scale: 2),
            isSelfEmployed: isSelfEmployed,
            rules: rules
        )

        // MARK: Capital gains

        let capitalGains = Self.capitalGainsTax(
            gains: max(0, adv.ukCapitalGains),
            taxableIncome: taxableEarnings + taxableSavings + taxableDividends,
            rules: rules,
            region: region
        )

        let incomeTax = earningsTax + savings.tax + dividends.tax
        let finalTax = incomeTax + nationalInsurance.total + capitalGains.tax
        let taxableIncome = taxableEarnings + taxableSavings + taxableDividends

        var supplementary: [TaxSupplementaryLine] = []
        if nationalInsurance.total > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: profile.incomeSourceType == .selfEmployed
                    ? String(localized: "National Insurance (Class 4)")
                    : String(localized: "National Insurance (Class 1)"),
                amount: nationalInsurance.total
            ))
        }
        if savings.tax > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Tax on savings interest"),
                amount: savings.tax
            ))
        }
        if dividends.tax > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Tax on dividends"),
                amount: dividends.tax
            ))
        }
        if capitalGains.tax > 0 {
            supplementary.append(TaxSupplementaryLine(
                title: String(localized: "Capital Gains Tax"),
                amount: capitalGains.tax
            ))
        }

        var assumptions: [String] = [
            String(localized: "Tax year runs 6 April to 5 April."),
            isScottish
                ? String(localized: "Scottish rates applied to earnings. Savings and dividends use UK-wide rates, which is correct wherever you live.")
                : String(localized: "England, Wales and Northern Ireland rates applied."),
        ]
        if personalAllowance < rules.personalAllowance {
            assumptions.append(String(localized: "Personal Allowance reduced to £\(Self.plain(personalAllowance)) because income is over £\(Self.plain(rules.personalAllowanceTaperThreshold))."))
        }
        if savings.allowanceApplied > 0 {
            assumptions.append(String(localized: "Personal Savings Allowance of £\(Self.plain(savings.allowanceApplied)) applied."))
        }
        if savings.startingRateApplied > 0 {
            assumptions.append(String(localized: "£\(Self.plain(savings.startingRateApplied)) of savings interest taxed at 0% under the starting rate for savings."))
        }
        if dividendIncome > 0 {
            assumptions.append(String(localized: "Dividend Allowance of £\(Self.plain(min(dividendIncome, rules.dividends.allowance))) applied."))
        }
        if adv.ukCapitalGains > 0 {
            assumptions.append(String(localized: "Capital gains annual exempt amount of £\(Self.plain(min(adv.ukCapitalGains, rules.capitalGains.annualExemptAmount))) applied."))
        }

        if !isSelfEmployed {
            assumptions.append(String(localized: "Class 1 National Insurance is charged on annual income as employment earnings. Pension income does not pay National Insurance."))
        }
        if niShare < 1 {
            assumptions.append(niShare == 0
                ? String(localized: "No National Insurance: you are over State Pension age for this tax year.")
                : String(localized: "National Insurance charged only on earnings before you reach State Pension age, spread evenly across the year."))
        }

        var warnings: [String] = []
        if incomeAfterRelief > rules.personalAllowanceTaperThreshold, incomeAfterRelief < rules.restOfUK.topRateThreshold {
            warnings.append(String(localized: "Between £\(Self.plain(rules.personalAllowanceTaperThreshold)) and £\(Self.plain(rules.restOfUK.topRateThreshold)) the tapered Personal Allowance makes the effective rate on this slice about 60%."))
        }
        if !UKTaxRuleTable.supportedYears.contains(Self.requestedTaxYear(for: profile)) {
            warnings.append(String(localized: "Figures for the year you selected are not held. The nearest year Vittora has was used instead."))
        }

        let exclusions: [String] = [
            String(localized: "Student loan repayments are not included."),
            String(localized: "Child Benefit High Income Charge is not included."),
            String(localized: "Marriage Allowance and Blind Person's Allowance are not included."),
            String(localized: "Pension annual allowance taper is not modelled — relief is applied as entered."),
            String(localized: "Residential property gains may be reported and paid separately; rates here match other assets."),
        ]

        return TaxEstimate(
            grossIncome: totalIncome,
            standardDeduction: personalAllowance,
            customDeductionsTotal: reliefApplied,
            taxableIncome: taxableIncome,
            bracketResults: earningsBrackets + savings.brackets + dividends.brackets,
            basicTax: incomeTax,
            rebate: 0,
            surcharge: 0,
            cess: 0,
            finalTax: finalTax,
            // Denominator includes gains, because CGT is in the numerator.
            effectiveRate: (totalIncome + max(0, adv.ukCapitalGains)) > 0
                ? (finalTax / (totalIncome + max(0, adv.ukCapitalGains))).rounded(scale: 4)
                : 0,
            marginalRate: Self.marginalRate(
                taxableEarnings: taxableEarnings,
                totalIncome: incomeAfterRelief,
                rules: rules,
                region: region
            ),
            country: .unitedKingdom,
            regimeLabel: isScottish
                ? String(localized: "Scotland")
                : String(localized: "England, Wales & NI"),
            supplementaryLines: supplementary,
            assumptions: assumptions,
            warnings: warnings,
            exclusions: exclusions,
            disclaimerKey: "tax.disclaimer.uk.v1",
            ruleSetID: rules.ruleSetID,
            rulesLastUpdated: Self.rulesLastUpdated
        )
    }
}

// MARK: - Components

extension UKTaxCalculator {

    /// £1 of allowance is lost for every £2 of income above the threshold, so the
    /// allowance is exhausted at threshold + 2 × allowance (£125,140 for 2025-26).
    nonisolated static func personalAllowance(
        totalIncome: Decimal,
        rules: UKTaxRuleTable.YearRules
    ) -> Decimal {
        guard totalIncome > rules.personalAllowanceTaperThreshold else {
            return rules.personalAllowance
        }
        let excess = totalIncome - rules.personalAllowanceTaperThreshold
        let reduction = (excess / rules.personalAllowanceTaperRatio).rounded(scale: 2)
        return max(0, rules.personalAllowance - reduction)
    }

    struct StreamResult: Sendable {
        let tax: Decimal
        let brackets: [TaxBracketResult]
        var allowanceApplied: Decimal = 0
        var startingRateApplied: Decimal = 0
    }

    /// Savings interest sits above earnings in the band order, so it is taxed at
    /// whatever band earnings have already reached.
    ///
    /// Two reliefs stack, in this order:
    /// - the **starting rate for savings** (£5,000 at 0%), reduced £1-for-£1 by
    ///   taxable non-savings income, so it is gone once earnings exceed it;
    /// - the **Personal Savings Allowance**, whose size depends on the band the
    ///   taxpayer lands in (£1,000 basic, £500 higher, nil additional).
    ///
    /// Scottish taxpayers use UK-wide rates here, so this deliberately does not
    /// take the Scottish bands — only their higher-rate threshold, for the tiering.
    nonisolated static func savingsTax(
        taxableSavings: Decimal,
        taxableEarnings: Decimal,
        incomeAfterRelief: Decimal,
        rules: UKTaxRuleTable.YearRules,
        region: UKTaxRuleTable.RegionBands
    ) -> StreamResult {
        guard taxableSavings > 0 else { return StreamResult(tax: 0, brackets: []) }

        let startingBand = max(0, rules.savings.startingRateBand - taxableEarnings)
        let atStartingRate = min(taxableSavings, startingBand)

        // The PSA tier follows total income, not savings alone.
        let allowance: Decimal
        if incomeAfterRelief > rules.restOfUK.topRateThreshold {
            allowance = rules.savings.allowanceAdditionalRate
        } else if incomeAfterRelief > rules.restOfUK.higherRateThreshold {
            allowance = rules.savings.allowanceHigherRate
        } else {
            allowance = rules.savings.allowanceBasicRate
        }

        let afterStarting = taxableSavings - atStartingRate
        let atAllowance = min(afterStarting, allowance)
        let chargeable = max(0, afterStarting - atAllowance)

        guard chargeable > 0 else {
            return StreamResult(
                tax: 0,
                brackets: [],
                allowanceApplied: atAllowance,
                startingRateApplied: atStartingRate
            )
        }

        // Savings use UK-wide rates (20/40/45) wherever the taxpayer lives. The
        // slice already occupied by earnings and by the 0% reliefs is skipped by
        // offsetting the band edges.
        let used = taxableEarnings + atStartingRate + atAllowance
        let ukBands = rules.restOfUK.bands
        let withOffset = ukBands.apply(to: used + chargeable)
        let withoutSavings = ukBands.apply(to: used)
        let tax = withOffset.reduce(Decimal(0)) { $0 + $1.taxAmount }
            - withoutSavings.reduce(Decimal(0)) { $0 + $1.taxAmount }

        return StreamResult(
            tax: max(0, tax.rounded(scale: 2)),
            brackets: [TaxBracketResult(
                label: String(localized: "Savings interest"),
                ratePercent: chargeable > 0 ? (max(0, tax) / chargeable * 100).rounded(scale: 2) : 0,
                taxableAmount: chargeable,
                taxAmount: max(0, tax.rounded(scale: 2))
            )],
            allowanceApplied: atAllowance,
            startingRateApplied: atStartingRate
        )
    }

    /// Dividends are the top slice of income and have their own three rates. The
    /// allowance is not a deduction — it uses up band, so a basic-rate taxpayer with
    /// a large dividend can still be pushed into the higher dividend rate by it.
    nonisolated static func dividendTax(
        taxableDividends: Decimal,
        otherTaxableIncome: Decimal,
        rules: UKTaxRuleTable.YearRules
    ) -> StreamResult {
        guard taxableDividends > 0 else { return StreamResult(tax: 0, brackets: []) }

        let allowance = min(taxableDividends, rules.dividends.allowance)
        let chargeable = taxableDividends - allowance

        // Basic and higher band edges are expressed on taxable income, so the
        // dividend slice starts where other income stopped — and the allowance
        // itself consumes band before the charge begins.
        let basicLimit = rules.restOfUK.bands[0].upper ?? 0
        let higherLimit = rules.restOfUK.bands[1].upper ?? 0
        var position = otherTaxableIncome + allowance
        var remaining = chargeable
        var brackets: [TaxBracketResult] = []
        var tax = Decimal(0)

        for (limit, rate, label) in [
            (basicLimit, rules.dividends.basicRate, String(localized: "Dividends (basic rate)")),
            (higherLimit, rules.dividends.higherRate, String(localized: "Dividends (higher rate)")),
            (Decimal.greatestFiniteMagnitude, rules.dividends.additionalRate, String(localized: "Dividends (additional rate)")),
        ] {
            guard remaining > 0 else { break }
            let room = max(0, limit - position)
            let slice = min(remaining, room)
            if slice > 0 {
                let sliceTax = (slice * rate / 100).rounded(scale: 2)
                brackets.append(TaxBracketResult(
                    label: label,
                    ratePercent: rate,
                    taxableAmount: slice,
                    taxAmount: sliceTax
                ))
                tax += sliceTax
                remaining -= slice
                position += slice
            }
            // An exhausted band is skipped; the position never moves backwards.
        }

        return StreamResult(tax: tax, brackets: brackets, allowanceApplied: allowance)
    }

    struct NIResult: Sendable {
        let total: Decimal
    }

    /// NI is on earnings only — never on savings, dividends or gains — and uses its
    /// own threshold rather than the personal allowance. Class 2 is not charged: it
    /// stopped being mandatory in 2024-25.
    nonisolated static func nationalInsurance(
        earnings: Decimal,
        isSelfEmployed: Bool,
        rules: UKTaxRuleTable.YearRules
    ) -> NIResult {
        let ni = rules.nationalInsurance
        guard earnings > ni.primaryThreshold else { return NIResult(total: 0) }

        let mainRate = isSelfEmployed ? ni.selfEmployedMainRate : ni.mainRate
        let upperRate = isSelfEmployed ? ni.selfEmployedUpperRate : ni.upperRate

        let mainBand = min(earnings, ni.upperEarningsLimit) - ni.primaryThreshold
        var total = (max(0, mainBand) * mainRate / 100).rounded(scale: 2)

        if earnings > ni.upperEarningsLimit {
            total += ((earnings - ni.upperEarningsLimit) * upperRate / 100).rounded(scale: 2)
        }
        return NIResult(total: total.rounded(scale: 2))
    }

    struct CGTResult: Sendable {
        let tax: Decimal
    }

    /// Gains sit above income for rate purposes: the basic-rate portion is whatever
    /// is left of the basic-rate band after income has been counted.
    ///
    /// Scottish taxpayers pay UK-wide CGT rates — CGT is not devolved — so the
    /// rest-of-UK basic-rate limit is used regardless of region.
    nonisolated static func capitalGainsTax(
        gains: Decimal,
        taxableIncome: Decimal,
        rules: UKTaxRuleTable.YearRules,
        region: UKTaxRuleTable.RegionBands
    ) -> CGTResult {
        guard gains > 0 else { return CGTResult(tax: 0) }

        let chargeable = max(0, gains - rules.capitalGains.annualExemptAmount)
        guard chargeable > 0 else { return CGTResult(tax: 0) }

        let basicLimit = rules.restOfUK.bands[0].upper ?? 0
        let basicRoom = max(0, basicLimit - taxableIncome)
        let atBasic = min(chargeable, basicRoom)
        let atHigher = chargeable - atBasic

        let tax = (atBasic * rules.capitalGains.basicRate / 100).rounded(scale: 2)
            + (atHigher * rules.capitalGains.higherRate / 100).rounded(scale: 2)
        return CGTResult(tax: tax)
    }

    /// The rate on the next pound of earnings. Inside the taper this is the headline
    /// band rate plus the allowance being withdrawn, which is what produces 60%.
    nonisolated static func marginalRate(
        taxableEarnings: Decimal,
        totalIncome: Decimal,
        rules: UKTaxRuleTable.YearRules,
        region: UKTaxRuleTable.RegionBands
    ) -> Decimal {
        let band = region.bands.last { taxableEarnings > $0.lower }
            ?? region.bands.first
        let bandRate = band?.ratePercent ?? 0

        if totalIncome > rules.personalAllowanceTaperThreshold,
           totalIncome <= rules.restOfUK.topRateThreshold {
            // Each extra £1 also removes 50p of allowance, which is then taxed at the
            // same band rate — so the effective rate is 1.5x the headline. At 40% that
            // is the familiar 60%; a Scottish advanced-rate payer sees 67.5%.
            let taperMultiplier = Decimal(string: "1.5") ?? 1
            return (bandRate * taperMultiplier).rounded(scale: 2)
        }
        return bandRate
    }

    // MARK: - Year resolution

    nonisolated static func requestedTaxYear(for profile: TaxProfile) -> Int {
        // "2025-26" -> 2025. A bare "2025" is accepted too.
        let leading = profile.financialYear.split(separator: "-").first ?? ""
        return Int(leading) ?? Calendar.current.component(.year, from: .now)
    }

    /// Share of the tax year whose earnings are liable to NI, given State
    /// Pension age. Class 1 stops on the SPA date (pro-rated across the year);
    /// Class 4 is due for the whole year in which SPA is reached and none after.
    nonisolated static func niLiableShareOfYear(dateOfBirth: Date?, taxYear: Int, isSelfEmployed: Bool) -> Decimal {
        guard let spa = statePensionAgeDate(dateOfBirth: dateOfBirth) else { return 1 }
        let calendar = Calendar(identifier: .gregorian)
        guard let start = calendar.date(from: DateComponents(year: taxYear, month: 4, day: 6)),
              let end = calendar.date(from: DateComponents(year: taxYear + 1, month: 4, day: 6))
        else { return 1 }
        if isSelfEmployed { return spa < start ? 0 : 1 }
        if spa <= start { return 0 }
        if spa >= end { return 1 }
        let daysBefore = calendar.dateComponents([.day], from: start, to: spa).day ?? 0
        let daysInYear = calendar.dateComponents([.day], from: start, to: end).day ?? 365
        guard daysInYear > 0 else { return 1 }
        return (Decimal(daysBefore) / Decimal(daysInYear)).rounded(scale: 6)
    }

    /// State Pension age under the Pensions Acts 2011/2014: 66 for those born
    /// before 6 April 1960; 66 plus one month per month of birth for 6 April
    /// 1960 – 5 March 1961; 67 from 6 March 1961. Not hardcoded to one age —
    /// the transition is live in 2026-28.
    nonisolated static func statePensionAgeDate(dateOfBirth: Date?) -> Date? {
        guard let dateOfBirth else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let birth = Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth)
        guard let year = birth.year, let month = birth.month, let day = birth.day,
              let birthDate = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        let isBefore = { (y: Int, m: Int, d: Int) in (year, month, day) < (y, m, d) }
        let months: Int
        if isBefore(1960, 4, 6) {
            months = 66 * 12
        } else if isBefore(1961, 3, 6) {
            // 6 Apr–5 May 1960 → +1 month … 6 Feb–5 Mar 1961 → +11 months.
            let shifted = calendar.date(byAdding: .day, value: -5, to: birthDate) ?? birthDate
            let parts = calendar.dateComponents([.year, .month], from: shifted)
            let index = ((parts.year ?? 1960) - 1960) * 12 + (parts.month ?? 4) - 4
            months = 66 * 12 + min(11, max(1, index + 1))
        } else {
            months = 67 * 12
        }
        return calendar.date(byAdding: .month, value: months, to: birthDate)
    }

    nonisolated static func supportedTaxYear(for profile: TaxProfile) -> Int {
        UKTaxRuleTable.resolvedTaxYear(requestedTaxYear(for: profile), in: UKTaxRuleTable.supportedYears)
    }

    /// Whole pounds for prose. Assumption strings read as sentences, not ledger rows.
    nonisolated static func plain(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
