import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Regressions from the 3 October 2026 tax-logic review
/// (`Docs/Tax/TAX_LOGIC_REVIEW_2026-10-03.md`, section 9).
///
/// Every expected figure is derived by hand from the cited rule, shown beside
/// the assertion, and NOT regenerated from the calculator under test. Inputs are
/// the review's reproduction inputs, unchanged. Money is built from integer or
/// string literals only.
@Suite("Tax review 2026-10-03 regressions")
@MainActor
struct TaxReviewRegressionTests {

    private static func d(_ string: String) -> Decimal { Decimal(string: string) ?? .nan }

    private static func dob(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private static func line(_ estimate: TaxEstimate, _ title: String) -> Decimal? {
        estimate.supplementaryLines.first { $0.title == title }?.amount
    }

    // MARK: - United States

    @Suite("United States")
    @MainActor
    struct UnitedStates {
        private func profile(
            year: String = "2026",
            wages: Decimal,
            dob: Date? = nil,
            status: USFilingStatus = .single,
            source: IncomeSourceType = .salaried,
            configure: (inout TaxAdvancedInputs) -> Void = { _ in }
        ) -> TaxProfile {
            var advanced = TaxAdvancedInputs()
            configure(&advanced)
            return TaxProfile(
                country: .unitedStates,
                annualIncome: wages,
                filingStatus: status,
                financialYear: year,
                incomeSourceType: source,
                dateOfBirth: dob,
                advancedInputs: advanced
            )
        }

        /// US-01. Single, 65+ in 2026, wages 50,000.
        ///   Standard 16,100 + aged increment 2,050 = 18,150; enhanced senior
        ///   deduction 6,000 (MAGI below 75,000). Taxable 25,850.
        ///   12,400 × 10% = 1,240 + 13,450 × 12% = 1,614 → 2,854.
        @Test func seniorDeductionsAreSeparate() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 50_000, dob: TaxReviewRegressionTests.dob(1955, 1, 1)))
            #expect(estimate.taxableIncome == 25_850)
            #expect(estimate.finalTax == 2_854)
        }

        /// US-01. 2024 has no enhanced deduction (it starts in 2025).
        ///   14,600 + 1,950 = 16,550; taxable 33,450.
        ///   11,600 × 10% = 1,160 + 21,850 × 12% = 2,622 → 3,782.
        @Test func noEnhancedSeniorDeductionIn2024() {
            let estimate = USTaxCalculator().calculate(profile: profile(year: "2024", wages: 50_000, dob: TaxReviewRegressionTests.dob(1955, 1, 1)))
            #expect(estimate.taxableIncome == 33_450)
            #expect(estimate.finalTax == 3_782)
        }

        /// US-01. The enhanced deduction phases out by 6% of MAGI over 75,000.
        ///   Wages 100,000: 6,000 − 6% × 25,000 = 4,500.
        ///   Taxable 100,000 − 18,150 − 4,500 = 77,350.
        ///   1,240 + 38,000 × 12% = 4,560 + 26,950 × 22% = 5,929 → 11,729.
        @Test func enhancedSeniorDeductionPhasesOut() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 100_000, dob: TaxReviewRegressionTests.dob(1955, 1, 1)))
            #expect(estimate.taxableIncome == 77_350)
            #expect(estimate.finalTax == 11_729)
        }

        /// US-01. Born 1 January 1962: the IRS treats you as 65 on the day
        ///   before your birthday, so you are 65 for 2026.
        @Test func januaryFirstBirthdayCountsForThePriorYear() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 50_000, dob: TaxReviewRegressionTests.dob(1962, 1, 1)))
            #expect(estimate.taxableIncome == 25_850)
        }

        /// US-02. 2026 single, wages 65,550 + LTCG 550.
        ///   Ordinary taxable 49,450 = the corrected 0% ceiling, so the 550 is at
        ///   15% = 82.50, and ordinary 1,240 + 37,050 × 12% = 5,686 → 5,768.50.
        ///   The Schedule D worksheet then takes the SMALLER of that and regular
        ///   tax on all 50,000 (1,240 + 37,600 × 12% = 5,752), because here the
        ///   15% gain rate exceeds the 12% bracket. Expected 5,752.
        ///   (The review's 5,768.50 omits the worksheet limit its US-03 section
        ///   requires; the old $50,000 ceiling gave 5,686.)
        @Test func preferentialThresholds2026() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 65_550) { $0.usLongTermCapitalGains = 550 })
            #expect(estimate.finalTax == 5_752)
        }

        /// US-03. Gains only: 60,000 LTCG − 16,100 standard = 43,900 taxable,
        ///   all under the 49,450 0% ceiling → 0.
        @Test func deductionShelterGainsOnlyIncome() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 0) { $0.usLongTermCapitalGains = 60_000 })
            #expect(estimate.finalTax == 0)
            #expect(estimate.taxableIncome == 43_900)
        }

        /// US-04. Other investment income is ordinary taxable income in addition
        ///   to wages (interest, non-qualified dividends).
        ///   60,000 − 16,100 = 43,900: 1,240 + 31,500 × 12% = 3,780 → 5,020.
        @Test func otherInvestmentIncomeIsOrdinaryIncome() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 50_000) { $0.usOtherInvestmentIncome = 10_000 })
            #expect(estimate.finalTax == 5_020)
        }

        /// US-04. Self-employed: SE tax, not employee FICA.
        ///   Net earnings 100,000 × 92.35% = 92,350; × 15.3% = 14,129.55.
        @Test func selfEmploymentTax() {
            let estimate = USTaxCalculator().calculate(profile: profile(wages: 100_000, source: .selfEmployed))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Self-employment tax")) == TaxReviewRegressionTests.d("14129.55"))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Social Security (employee)")) == nil)
            // Half of SE tax (7,064.78 rounded to the cent) is above the line:
            // 100,000 − 7,064.78 − 16,100 = 76,835.22.
            #expect(estimate.taxableIncome == TaxReviewRegressionTests.d("76835.22"))
        }

        /// US-05. 2024 Social Security wage base 168,600 × 6.2% = 10,453.20.
        @Test func socialSecurityWageBase2024() {
            let estimate = USTaxCalculator().calculate(profile: profile(year: "2024", wages: 200_000))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Social Security (employee)")) == TaxReviewRegressionTests.d("10453.20"))
        }

        /// US-05. 2026 IRA limit with age-50 catch-up: 7,500 + 1,100 = 8,600.
        @Test func iraCatchUp2026() {
            #expect(USContributionHeadroomEngine.statutoryIRALimit(taxYear: 2026, age50Plus: true) == 8_600)
        }

        /// US-05. 2024 limits: 401(k) 23,000; HSA 4,150 / 8,300.
        @Test func contributionLimits2024() {
            #expect(USContributionHeadroomEngine.statutory401kLimit(taxYear: 2024, age50Plus: false) == 23_000)
            #expect(USContributionHeadroomEngine.statutoryHSALimit(taxYear: 2024, familyCoverage: false) == 4_150)
            #expect(USContributionHeadroomEngine.statutoryHSALimit(taxYear: 2024, familyCoverage: true) == 8_300)
        }

        /// US-06. Ages 60–63 get the 11,250 401(k) catch-up in 2025/2026:
        ///   24,500 + 11,250 = 35,750 for 2026.
        @Test func superCatchUpAges60To63() {
            let profile = profile(wages: 150_000, dob: TaxReviewRegressionTests.dob(1964, 6, 1))
            let utilization = USContributionHeadroomEngine.utilizations(profile: profile, taxYear: 2026)
            #expect(utilization.first { $0.id == "401k" }?.statutoryLimit == 35_750)
        }
    }

    // MARK: - United Kingdom

    @Suite("United Kingdom")
    @MainActor
    struct UnitedKingdom {
        private func profile(
            year: String = "2025-26",
            income: Decimal,
            dob: Date? = nil,
            dividends: Decimal = 0,
            deductions: [TaxDeduction] = []
        ) -> TaxProfile {
            var advanced = TaxAdvancedInputs()
            advanced.ukDividendIncome = dividends
            return TaxProfile(
                country: .unitedKingdom,
                annualIncome: income,
                customDeductions: deductions,
                financialYear: year,
                incomeSourceType: .salaried,
                dateOfBirth: dob,
                advancedInputs: advanced
            )
        }

        /// UK-01. 120,000: allowance 12,570 − 10,000 = 2,570; taxable 117,430,
        ///   still below the £125,140 additional-rate edge.
        ///   37,700 × 20% = 7,540 + 79,730 × 40% = 31,892 → 39,432.
        ///   NI (50,270 − 12,570) × 8% = 3,016 + 69,730 × 2% = 1,394.60 → 4,410.60.
        @Test func additionalRateStartsAt125140() {
            let estimate = UKTaxCalculator().calculate(profile: profile(income: 120_000))
            #expect(estimate.basicTax == 39_432)
            #expect(estimate.finalTax == TaxReviewRegressionTests.d("43842.60"))
            #expect(estimate.marginalRate == 60)
        }

        /// UK-02. Earnings 200,000 + dividends 10,000: income already in the
        ///   additional band, so (10,000 − 500) × 39.35% = 3,738.25.
        @Test func dividendStackingNeverMovesBackwards() {
            let estimate = UKTaxCalculator().calculate(profile: profile(income: 200_000, dividends: 10_000))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Tax on dividends")) == TaxReviewRegressionTests.d("3738.25"))
        }

        /// UK-03. 110,000 with a 10,000 net-pay pension relief: adjusted net
        ///   income 100,000 keeps the full allowance. Taxable 87,430:
        ///   7,540 + 49,730 × 40% = 19,892 → 27,432.
        @Test func allowanceTaperUsesAdjustedNetIncome() {
            let pension = TaxDeduction(name: "Pension", amount: 10_000)
            let estimate = UKTaxCalculator().calculate(profile: profile(income: 110_000, deductions: [pension]))
            #expect(estimate.standardDeduction == 12_570)
            #expect(estimate.basicTax == 27_432)
        }

        /// UK-03. Relief reduces savings/dividend income when there are no earnings.
        ///   Dividends 20,000, relief 5,000 → 15,000; allowance 12,570 leaves
        ///   2,430; dividend allowance 500, 1,930 × 8.75% = 168.88 (rounded).
        @Test func reliefReducesDividendsWithoutEarnings() {
            let gift = TaxDeduction(name: "Relief", amount: 5_000)
            let estimate = UKTaxCalculator().calculate(profile: profile(income: 0, dividends: 20_000, deductions: [gift]))
            #expect(estimate.basicTax == TaxReviewRegressionTests.d("168.88"))
        }

        /// UK-04. 2026-27, wages 30,000 + dividends 3,000.
        ///   Earnings 17,430 × 20% = 3,486; dividends 2,500 × 10.75% = 268.75;
        ///   NI 17,430 × 8% = 1,394.40. Total 5,149.15.
        @Test func dividendRates2026() {
            let estimate = UKTaxCalculator().calculate(profile: profile(year: "2026-27", income: 30_000, dividends: 3_000))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Tax on dividends")) == TaxReviewRegressionTests.d("268.75"))
            #expect(estimate.finalTax == TaxReviewRegressionTests.d("5149.15"))
            #expect(estimate.ruleSetID == "UK_TY2026_27")
        }

        /// UK-04. Scotland 2026-27, 30,000: taxable 17,430.
        ///   3,967 × 19% = 753.73 + 12,989 × 20% = 2,597.80 + 474 × 21% = 99.54 → 3,451.07.
        @Test func scottishBands2026() {
            var p = profile(year: "2026-27", income: 30_000)
            p.advancedInputs.ukIsScottishTaxpayer = true
            let estimate = UKTaxCalculator().calculate(profile: p)
            #expect(estimate.basicTax == TaxReviewRegressionTests.d("3451.07"))
        }

        /// UK-05. Over State Pension age for the whole 2025-26 year: no employee NI.
        @Test func noClass1PastStatePensionAge() {
            let estimate = UKTaxCalculator().calculate(profile: profile(income: 30_000, dob: TaxReviewRegressionTests.dob(1950, 1, 1)))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "National Insurance (Class 1)")) == nil)
            #expect(estimate.finalTax == 3_486)
        }
    }

    // MARK: - India

    @Suite("India")
    @MainActor
    struct India {
        private func profile(
            income: Decimal,
            regime: IndiaRegime,
            source: IncomeSourceType,
            dob: Date? = nil,
            stcg: Decimal = 0,
            ltcg: Decimal = 0,
            year: String = "2025-26"
        ) -> TaxProfile {
            var advanced = TaxAdvancedInputs()
            advanced.indiaEquitySTCG = stcg
            advanced.indiaEquityLTCG = ltcg
            return TaxProfile(
                country: .india,
                annualIncome: income,
                indiaRegime: regime,
                financialYear: year,
                incomeSourceType: source,
                dateOfBirth: dob,
                advancedInputs: advanced
            )
        }

        /// IN-01. Old regime, salary 550,100: taxable 500,100 > 5L, so no 87A
        ///   rebate and no marginal relief (that is new-regime only).
        ///   12,500 + 100 × 20% = 12,520 × 1.04 = 13,020.80.
        @Test func oldRegimeRebateHasNoMarginalRelief() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 550_100, regime: .oldRegime, source: .salaried))
            #expect(estimate.rebate == 0)
            #expect(estimate.finalTax == TaxReviewRegressionTests.d("13020.80"))
        }

        /// IN-02a. New regime, salary 1,275,000 + STCG 200,000. Total income
        ///   14L > 12L: no rebate. Tax 60,000 + 40,000 = 100,000; no marginal
        ///   relief (excess 2L > tax). × 1.04 = 104,000.
        @Test func rebateEligibilityUsesTotalIncome() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 1_275_000, regime: .newRegime, source: .salaried, stcg: 200_000))
            #expect(estimate.rebate == 0)
            #expect(estimate.finalTax == 104_000)
        }

        /// IN-02b. Old regime, business 300,000 + STCG 100,000. Total 4L ≤ 5L.
        ///   Ordinary 2,500 + §111A 20,000 = 22,500 eligible; rebate 12,500;
        ///   10,000 × 1.04 = 10,400.
        @Test func oldRegimeRebateCoversShortTermGains() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 300_000, regime: .oldRegime, source: .selfEmployed, stcg: 100_000))
            #expect(estimate.rebate == 12_500)
            #expect(estimate.finalTax == 10_400)
        }

        /// IN-03. New regime, salary 5,050,000: total income 4,975,000 < 50L,
        ///   so no surcharge. Tax 300,000 + 2,575,000 × 30% = 1,072,500 × 1.04
        ///   = 1,115,400.
        @Test func surchargeUsesTotalIncome() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 5_050_000, regime: .newRegime, source: .salaried))
            #expect(estimate.surcharge == 0)
            #expect(estimate.finalTax == 1_115_400)
        }

        /// IN-04. New regime, business 4,980,000 + STCG 50,000 = 50.3L.
        ///   At the 50L threshold (gain held fixed): 1,065,000 + 10,000 =
        ///   1,075,000; ceiling 1,075,000 + 30,000 = 1,105,000. Actual before
        ///   surcharge 1,084,000 → surcharge 21,000. × 1.04 = 1,149,200.
        @Test func surchargeMarginalReliefAtTotalIncomeThreshold() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 4_980_000, regime: .newRegime, source: .selfEmployed, stcg: 50_000))
            #expect(estimate.surcharge == 21_000)
            #expect(estimate.finalTax == 1_149_200)
        }

        /// IN-05. DOB 1965-10-01 turns 60 during FY 2025-26: senior slabs.
        ///   Old regime business 700,000: 10,000 + 40,000 = 50,000 × 1.04 = 52,000.
        @Test func seniorAgeAttainedDuringTheYear() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 700_000, regime: .oldRegime, source: .selfEmployed, dob: TaxReviewRegressionTests.dob(1965, 10, 1)))
            #expect(estimate.finalTax == 52_000)
        }

        /// IN-06. New regime, no ordinary income, STCG 100,000: the unused 4L
        ///   basic exemption covers the gain → 0.
        @Test func unusedBasicExemptionCoversGains() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 0, regime: .newRegime, source: .selfEmployed, stcg: 100_000))
            #expect(estimate.finalTax == 0)
        }

        /// IN-09. FY 2026-27 has its own rule-set identity.
        @Test func taxYear2026HasItsOwnRuleSet() {
            let estimate = IndiaTaxCalculator().calculate(profile: profile(income: 1_000_000, regime: .newRegime, source: .salaried, year: "2026-27"))
            #expect(estimate.ruleSetID == "IN_FY2026_27")
        }
    }

    // MARK: - Australia

    @Suite("Australia")
    @MainActor
    struct Australia {
        private func profile(
            year: String,
            income: Decimal,
            cover: Bool,
            superContributions: Decimal = 0
        ) -> TaxProfile {
            var advanced = TaxAdvancedInputs()
            advanced.auHasPrivateHospitalCover = cover
            advanced.auConcessionalSuper = superContributions
            return TaxProfile(
                country: .australia,
                annualIncome: income,
                financialYear: year,
                advancedInputs: advanced
            )
        }

        /// AU-01. 2026-27, 50,000, cover held.
        ///   26,800 × 15% = 4,020 + 5,000 × 30% = 1,500 → 5,520;
        ///   LITO 700 − 375 − 75 = 250 → 5,270; Medicare 1,000 → 6,270.
        @Test func rateCut2026() {
            let estimate = AUTaxCalculator().calculate(profile: profile(year: "2026-27", income: 50_000, cover: true))
            #expect(estimate.finalTax == 6_270)
            #expect(estimate.ruleSetID == "AU_TY2026_27")
        }

        /// AU-02. 2025-26, 28,000 is below the $28,011 low-income threshold.
        ///   9,800 × 16% = 1,568 − LITO 700 = 868; levy 0.
        @Test func medicareLowIncomeThreshold2025() {
            let estimate = AUTaxCalculator().calculate(profile: profile(year: "2025-26", income: 28_000, cover: true))
            #expect(estimate.cess == 0)
            #expect(estimate.finalTax == 868)
        }

        /// AU-02. Inside the shade-in, levy = min(2% × income, 10% × excess).
        ///   30,000: 10% × 1,989 = 198.90.
        @Test func medicareShadeIn() {
            let estimate = AUTaxCalculator().calculate(profile: profile(year: "2025-26", income: 30_000, cover: true))
            #expect(estimate.cess == TaxReviewRegressionTests.d("198.90"))
        }

        /// AU-03. 2026-27, 103,000, no cover: below the $105,000 tier → no MLS.
        ///   26,800 × 15% = 4,020 + 58,000 × 30% = 17,400 → 21,420; Medicare
        ///   2,060 → 23,480.
        @Test func surchargeTiers2026() {
            let estimate = AUTaxCalculator().calculate(profile: profile(year: "2026-27", income: 103_000, cover: false))
            #expect(estimate.surcharge == 0)
            #expect(estimate.finalTax == 23_480)
        }

        /// AU-04. 2025-26, 120,000 with 20,000 deductible super, no cover.
        ///   MLS income adds the super back: 120,000 → 1.25% tier, charged on
        ///   taxable 100,000 = 1,250.
        @Test func surchargeTierUsesMLSIncome() {
            let estimate = AUTaxCalculator().calculate(profile: profile(year: "2025-26", income: 120_000, cover: false, superContributions: 20_000))
            #expect(estimate.surcharge == 1_250)
        }
    }

    // MARK: - Canada

    @Suite("Canada")
    @MainActor
    struct Canada {
        private func profile(
            year: String = "2025",
            income: Decimal,
            province: CAProvince,
            source: IncomeSourceType = .salaried
        ) -> TaxProfile {
            var advanced = TaxAdvancedInputs()
            advanced.caProvince = province
            return TaxProfile(
                country: .canada,
                annualIncome: income,
                financialYear: year,
                incomeSourceType: source,
                advancedInputs: advanced
            )
        }

        /// CA-02. Quebec 2025, 60,000: QPP (60,000 − 3,500) × 6.40% = 3,616.
        @Test func quebecPensionPlanRate() {
            let estimate = CATaxCalculator().calculate(profile: profile(income: 60_000, province: .quebec))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "QPP contribution")) == 3_616)
        }

        /// CA-03. Ontario 2025, 60,000.
        ///   Enhanced CPP deduction 56,500 × 1% = 565 → taxable 59,435.
        ///   Federal: 57,375 × 14.5% = 8,319.38 + 2,060 × 20.5% = 422.30 → 8,741.68.
        ///   Credits (16,129 + base CPP 2,796.75 + EI 984) × 14.5% = 2,886.91.
        ///   Federal tax 5,854.77.
        @Test func contributionDeductionsAndCredits() {
            let estimate = CATaxCalculator().calculate(profile: profile(income: 60_000, province: .ontario))
            #expect(estimate.taxableIncome == 59_435)
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "Federal tax")) == TaxReviewRegressionTests.d("5854.77"))
        }

        /// CA-04. Ontario 2025 self-employed 60,000: both CPP shares
        ///   56,500 × 11.9% = 6,723.50; no EI.
        @Test func selfEmployedPayBothShares() {
            let estimate = CATaxCalculator().calculate(profile: profile(income: 60_000, province: .ontario, source: .selfEmployed))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "CPP contribution")) == TaxReviewRegressionTests.d("6723.50"))
            #expect(TaxReviewRegressionTests.line(estimate, String(localized: "EI premium")) == nil)
        }

        /// CA-05. Corrected 2025 provincial amounts.
        @Test func provincialAmounts2025() {
            let rules = CATaxRuleTable.rules(for: 2025)
            #expect(rules.provinces[.princeEdwardIsland]?.basicPersonalAmount == 14_650)
            #expect(rules.provinces[.saskatchewan]?.basicPersonalAmount == 19_491)
            #expect(rules.provinces[.manitoba]?.basicPersonalAmount == 15_780)
            #expect(rules.provinces[.manitoba]?.brackets.first?.upper == 47_000)
        }

        /// CA-01. 2026 has its own tables: 14% lowest rate, 58,523 first edge.
        @Test func year2026Tables() {
            let estimate = CATaxCalculator().calculate(profile: profile(year: "2026", income: 60_000, province: .ontario))
            #expect(estimate.ruleSetID == "CA_TY2026_ON")
            #expect(estimate.bracketResults.first?.ratePercent == 14)
        }

        /// CA-06. Ontario 2025, 120,000: 26% + 11.16% × 1.56 = 43.4096%.
        @Test func marginalRateIncludesOntarioSurtax() {
            let estimate = CATaxCalculator().calculate(profile: profile(income: 120_000, province: .ontario))
            #expect(estimate.marginalRate == TaxReviewRegressionTests.d("43.4096"))
        }
    }
}
