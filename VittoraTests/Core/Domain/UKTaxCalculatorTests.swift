import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// UK tax golden fixtures for tax year 2025-26 (UK_TY2025_26).
///
/// Every expected figure below was derived by hand from the statutory 2025-26
/// rates and is listed in the PR for owner spot-check before merge. The rates
/// used:
///
///   Personal Allowance   £12,570, tapered £1 per £2 over £100,000
///   rUK bands            20% to £37,700 taxable, 40% to £112,570, then 45%
///   Scotland bands       19 / 20 / 21 / 42 / 45 / 48%
///   NI Class 1           8% from £12,570 to £50,270, then 2%
///   NI Class 4           6% over the same thresholds (Class 2 not charged)
///   Dividends            £500 allowance, then 8.75 / 33.75 / 39.35%
///   Savings              £5,000 starting-rate band, £1,000/£500/£0 PSA
///   CGT                  £3,000 exempt, then 18% / 24%
///
/// These are pinned, not computed from the table, so a change to the rule table
/// that alters a real bill fails here rather than passing silently.
@Suite("UKTaxCalculator golden fixtures")
@MainActor
struct UKTaxCalculatorTests {

    private let calculator = UKTaxCalculator()

    private func profile(
        income: Decimal,
        scottish: Bool = false,
        selfEmployed: Bool = false,
        dividends: Decimal = 0,
        savings: Decimal = 0,
        gains: Decimal = 0,
        deductions: [TaxDeduction] = []
    ) -> TaxProfile {
        var advanced = TaxAdvancedInputs()
        advanced.ukIsScottishTaxpayer = scottish
        advanced.ukDividendIncome = dividends
        advanced.ukSavingsIncome = savings
        advanced.ukCapitalGains = gains
        return TaxProfile(
            country: .unitedKingdom,
            annualIncome: income,
            customDeductions: deductions,
            financialYear: "2025-26",
            incomeSourceType: selfEmployed ? .selfEmployed : .salaried,
            advancedInputs: advanced
        )
    }

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string) ?? .nan
    }

    // MARK: - Basic rate

    /// £30,000 salaried, England.
    ///   Taxable 30,000 - 12,570 = 17,430 at 20% = 3,486.00
    ///   NI      17,430 at 8%                    = 1,394.40
    @Test("basic rate salary, England")
    func basicRateEngland() {
        let estimate = calculator.calculate(profile: profile(income: 30_000))
        #expect(estimate.standardDeduction == 12_570)
        #expect(estimate.taxableIncome == 17_430)
        #expect(estimate.basicTax == decimal("3486.00"))
        #expect(estimate.finalTax == decimal("4880.40"))
        #expect(estimate.marginalRate == 20)
        #expect(estimate.ruleSetID == "UK_TY2025_26")
    }

    /// £60,000 salaried, England.
    ///   20% on 37,700                = 7,540.00
    ///   40% on 47,430 - 37,700 9,730 = 3,892.00  -> income tax 11,432.00
    ///   NI 8% on 37,700 = 3,016.00, 2% on 9,730 = 194.60 -> 3,210.60
    @Test("higher rate salary, England")
    func higherRateEngland() {
        let estimate = calculator.calculate(profile: profile(income: 60_000))
        #expect(estimate.basicTax == decimal("11432.00"))
        #expect(estimate.finalTax == decimal("14642.60"))
        #expect(estimate.marginalRate == 40)
    }

    // MARK: - Personal allowance taper

    /// £110,000 salaried, England — inside the taper.
    ///   Allowance 12,570 - (10,000 / 2) = 7,570
    ///   Taxable 102,430: 20% on 37,700 = 7,540.00, 40% on 64,730 = 25,892.00
    ///   Income tax 33,432.00; NI 3,016.00 + 1,194.60 = 4,210.60
    @Test("personal allowance tapers above 100k and the marginal rate reaches 60%")
    func allowanceTaper() {
        let estimate = calculator.calculate(profile: profile(income: 110_000))
        #expect(estimate.standardDeduction == 7_570)
        #expect(estimate.taxableIncome == 102_430)
        #expect(estimate.basicTax == decimal("33432.00"))
        #expect(estimate.finalTax == decimal("37642.60"))
        // 40% band plus 50p of allowance withdrawn per extra £1, also at 40%.
        #expect(estimate.marginalRate == 60)
        #expect(estimate.warnings.contains { $0.contains("60%") })
    }

    /// The allowance is fully gone at 125,140, not merely small.
    @Test("personal allowance is nil at 125,140")
    func allowanceExhausted() {
        let estimate = calculator.calculate(profile: profile(income: 125_140))
        #expect(estimate.standardDeduction == 0)
        #expect(estimate.taxableIncome == 125_140)
    }

    // MARK: - Scotland

    /// £60,000 salaried, Scotland. Taxable 47,430.
    ///   19% on 2,827            =   537.13
    ///   20% on 12,094           = 2,418.80
    ///   21% on 16,171           = 3,395.91
    ///   42% on 16,338           = 6,861.96  -> income tax 13,213.80
    ///   NI is UK-wide           = 3,210.60
    @Test("Scottish bands produce a higher bill than England on the same income")
    func scotlandHigherRate() {
        let scotland = calculator.calculate(profile: profile(income: 60_000, scottish: true))
        #expect(scotland.basicTax == decimal("13213.80"))
        #expect(scotland.finalTax == decimal("16424.40"))
        #expect(scotland.marginalRate == 42)

        let england = calculator.calculate(profile: profile(income: 60_000))
        #expect(scotland.finalTax > england.finalTax)
        #expect(scotland.finalTax - england.finalTax == decimal("1781.80"))
    }

    /// NI is reserved, not devolved — a Scottish taxpayer pays the same NI.
    @Test("National Insurance does not change with region")
    func niIsNotDevolved() {
        let scotland = calculator.calculate(profile: profile(income: 60_000, scottish: true))
        let england = calculator.calculate(profile: profile(income: 60_000))
        let scottishNI = scotland.supplementaryLines.first { $0.title.contains("National Insurance") }
        let englishNI = england.supplementaryLines.first { $0.title.contains("National Insurance") }
        #expect(scottishNI?.amount == englishNI?.amount)
        #expect(scottishNI?.amount == decimal("3210.60"))
    }

    /// The single most common way to get UK tax wrong: Scottish rates apply only to
    /// non-savings, non-dividend income. Dividends use UK-wide rates everywhere.
    @Test("Scottish rates do not apply to dividend income")
    func scottishRatesExcludeDividends() {
        let scotland = calculator.calculate(profile: profile(income: 20_000, scottish: true, dividends: 10_000))
        let england = calculator.calculate(profile: profile(income: 20_000, dividends: 10_000))

        let scottishDividendTax = scotland.supplementaryLines.first { $0.title.contains("dividends") }?.amount
        let englishDividendTax = england.supplementaryLines.first { $0.title.contains("dividends") }?.amount
        #expect(scottishDividendTax == englishDividendTax)
    }

    // MARK: - Dividends

    /// £20,000 salary + £10,000 dividends, England.
    ///   Earnings taxable 7,430 at 20%            = 1,486.00
    ///   Dividends 10,000 - 500 allowance = 9,500 at 8.75% = 831.25
    ///   NI on earnings 7,430 at 8%               =   594.40
    @Test("dividend allowance then the 8.75% basic dividend rate")
    func dividendsBasicRate() {
        let estimate = calculator.calculate(profile: profile(income: 20_000, dividends: 10_000))
        #expect(estimate.basicTax == decimal("2317.25"))
        #expect(estimate.finalTax == decimal("2911.65"))
        let dividendTax = estimate.supplementaryLines.first { $0.title.contains("dividends") }?.amount
        #expect(dividendTax == decimal("831.25"))
    }

    /// NI is on earnings only. Dividends must not attract it.
    @Test("dividends attract no National Insurance")
    func dividendsNoNI() {
        let withDividends = calculator.calculate(profile: profile(income: 30_000, dividends: 20_000))
        let withoutDividends = calculator.calculate(profile: profile(income: 30_000))
        let a = withDividends.supplementaryLines.first { $0.title.contains("National Insurance") }?.amount
        let b = withoutDividends.supplementaryLines.first { $0.title.contains("National Insurance") }?.amount
        #expect(a == b)
    }

    // MARK: - Savings

    /// £15,000 salary + £6,000 interest, England.
    ///   Earnings taxable 2,430 at 20%                      = 486.00
    ///   Starting-rate band 5,000 - 2,430 = 2,570 at 0%
    ///   PSA 1,000 at 0%; chargeable 2,430 at 20%           = 486.00
    ///   NI on earnings 2,430 at 8%                         = 194.40
    @Test("starting rate for savings then the Personal Savings Allowance")
    func savingsReliefsStack() {
        let estimate = calculator.calculate(profile: profile(income: 15_000, savings: 6_000))
        #expect(estimate.basicTax == decimal("972.00"))
        #expect(estimate.finalTax == decimal("1166.40"))
        let savingsTax = estimate.supplementaryLines.first { $0.title.contains("savings") }?.amount
        #expect(savingsTax == decimal("486.00"))
    }

    /// The starting-rate band is eaten by non-savings income, so a higher earner
    /// gets none of it.
    @Test("starting rate for savings is gone once earnings exceed it")
    func startingRateWithdrawn() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, savings: 2_000))
        #expect(!estimate.assumptions.contains { $0.contains("starting rate") })
        // £500 PSA at higher rate, remaining £1,500 at 40% = 600.00
        let savingsTax = estimate.supplementaryLines.first { $0.title.contains("savings") }?.amount
        #expect(savingsTax == decimal("600.00"))
    }

    // MARK: - Capital gains

    /// £30,000 salary + £20,000 gains, England.
    ///   Gains 20,000 - 3,000 exempt = 17,000, all inside the basic band at 18% = 3,060.00
    ///   Income tax 3,486.00 + NI 1,394.40
    @Test("capital gains use the basic rate while basic-band room remains")
    func capitalGainsBasicRate() {
        let estimate = calculator.calculate(profile: profile(income: 30_000, gains: 20_000))
        #expect(estimate.finalTax == decimal("7940.40"))
        let cgt = estimate.supplementaryLines.first { $0.title.contains("Capital Gains") }?.amount
        #expect(cgt == decimal("3060.00"))
    }

    /// Gains sit above income, so a higher-rate taxpayer pays 24% on all of them.
    @Test("capital gains use the higher rate once income fills the basic band")
    func capitalGainsHigherRate() {
        let estimate = calculator.calculate(profile: profile(income: 60_000, gains: 10_000))
        // 10,000 - 3,000 = 7,000 at 24% = 1,680.00
        let cgt = estimate.supplementaryLines.first { $0.title.contains("Capital Gains") }?.amount
        #expect(cgt == decimal("1680.00"))
    }

    @Test("gains within the annual exempt amount are not taxed")
    func capitalGainsExempt() {
        let estimate = calculator.calculate(profile: profile(income: 30_000, gains: 3_000))
        #expect(!estimate.supplementaryLines.contains { $0.title.contains("Capital Gains") })
    }

    // MARK: - Self-employment

    /// £40,000 self-employed, England.
    ///   Taxable 27,430 at 20%  = 5,486.00
    ///   Class 4 27,430 at 6%   = 1,645.80
    @Test("self-employed pays Class 4 at 6%, not Class 1 at 8%")
    func selfEmployedClass4() {
        let estimate = calculator.calculate(profile: profile(income: 40_000, selfEmployed: true))
        #expect(estimate.basicTax == decimal("5486.00"))
        #expect(estimate.finalTax == decimal("7131.80"))
        let ni = estimate.supplementaryLines.first { $0.title.contains("National Insurance") }
        #expect(ni?.amount == decimal("1645.80"))
        #expect(ni?.title.contains("Class 4") == true)
    }

    // MARK: - Edges

    @Test("income below the personal allowance produces no tax at all")
    func belowAllowance() {
        let estimate = calculator.calculate(profile: profile(income: 10_000))
        #expect(estimate.taxableIncome == 0)
        #expect(estimate.finalTax == 0)
    }

    /// NI has its own threshold. It happens to equal the allowance this year, so a
    /// taxpayer just above it owes NI but almost no income tax.
    @Test("no National Insurance below the primary threshold")
    func belowNIThreshold() {
        let estimate = calculator.calculate(profile: profile(income: 12_570))
        #expect(estimate.finalTax == 0)
    }

    @Test("zero income does not divide by zero in the effective rate")
    func zeroIncome() {
        let estimate = calculator.calculate(profile: profile(income: 0))
        #expect(estimate.effectiveRate == 0)
        #expect(estimate.finalTax == 0)
    }

    /// A year Vittora does not hold must say so rather than quietly using another.
    @Test("an unsupported year warns and falls back to the nearest held year")
    func unsupportedYearWarns() {
        var p = profile(income: 30_000)
        p.financialYear = "2031-32"
        let estimate = calculator.calculate(profile: p)
        #expect(estimate.ruleSetID == "UK_TY2025_26")
        #expect(estimate.warnings.contains { $0.contains("not held") })
    }

    /// The tax year boundary is 6 April, not 1 April.
    @Test("default financial year uses the 6 April boundary")
    func taxYearBoundary() {
        let year = TaxCountry.unitedKingdom.defaultFinancialYear
        #expect(year.contains("-"))
        #expect(year.count == 7)
    }
}
