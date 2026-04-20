import Foundation
import Testing
@testable import Vittora

/// Regression suite pinning exact computed values for IndiaTaxCalculator and
/// USTaxCalculator. Each test encodes the expected statutory result for a
/// specific profile so any rule-table or arithmetic change is caught immediately.
@Suite("Tax Calculator Regression Tests")
struct TaxCalculatorRegressionTests {

    // MARK: - India helpers

    private func indiaProfile(
        annualIncome: Decimal,
        regime: IndiaRegime,
        financialYear: String = "2024-25",
        incomeSourceType: IncomeSourceType = .salaried,
        dateOfBirth: Date? = nil,
        customDeductions: [TaxDeduction] = []
    ) -> TaxProfile {
        TaxProfile(
            country: .india,
            annualIncome: annualIncome,
            indiaRegime: regime,
            customDeductions: customDeductions,
            financialYear: financialYear,
            incomeSourceType: incomeSourceType,
            dateOfBirth: dateOfBirth
        )
    }

    private func dob(year: Int) -> Date {
        let components = DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: 1, day: 1)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: - India FY 2024-25 New Regime

    @Suite("India FY 2024-25 New Regime")
    struct IndiaFY2024NewRegime {
        let calc = IndiaTaxCalculator()

        private func profile(income: Decimal, source: IncomeSourceType = .salaried) -> TaxProfile {
            TaxProfile(
                country: .india,
                annualIncome: income,
                indiaRegime: .newRegime,
                financialYear: "2024-25",
                incomeSourceType: source
            )
        }

        @Test("₹5L salaried – rebate eliminates tax")
        func fiveLakhSalaryZeroTax() {
            // taxable = 5,00,000 − 75,000 = 4,25,000
            // basicTax = 1,25,000 × 5% = 6,250; rebate = 6,250 → finalTax = 0
            let result = calc.calculate(profile: profile(income: 5_00_000))
            #expect(result.taxableIncome  == 4_25_000)
            #expect(result.standardDeduction == 75_000)
            #expect(result.basicTax  == 6_250)
            #expect(result.rebate    == 6_250)
            #expect(result.finalTax  == 0)
        }

        @Test("₹7L salaried – rebate eliminates tax at top of threshold")
        func sevenLakhSalaryZeroTax() {
            // taxable = 7,00,000 − 75,000 = 6,25,000
            // basicTax = 4L×5% + 25K×5% = 20,000 + 1,250 = ... wait
            // slabs: 3L–7L at 5%  → taxable above 3L = 3,25,000 × 5% = 16,250
            // rebate = min(16,250, 25,000) = 16,250 → finalTax = 0
            let result = calc.calculate(profile: profile(income: 7_00_000))
            #expect(result.taxableIncome == 6_25_000)
            #expect(result.basicTax  == 16_250)
            #expect(result.rebate    == 16_250)
            #expect(result.finalTax  == 0)
        }

        @Test("₹15L salaried – standard slab calculation")
        func fifteenLakhSalaryStandardCalc() {
            // taxable = 15,00,000 − 75,000 = 14,25,000
            // 3L–7L: 4,00,000 × 5% = 20,000
            // 7L–10L: 3,00,000 × 10% = 30,000
            // 10L–12L: 2,00,000 × 15% = 30,000
            // 12L–14.25L: 2,25,000 × 20% = 45,000 → basicTax = 1,25,000
            // rebate = 0 (taxable > 7L threshold), cess = 5,000, finalTax = 1,30,000
            let result = calc.calculate(profile: profile(income: 15_00_000))
            #expect(result.taxableIncome == 14_25_000)
            #expect(result.basicTax  == 1_25_000)
            #expect(result.rebate    == 0)
            #expect(result.cess      == 5_000)
            #expect(result.surcharge == 0)
            #expect(result.finalTax  == 1_30_000)
        }

        @Test("₹10L self-employed – no standard deduction")
        func tenLakhSelfEmployedNoStandardDeduction() {
            // taxable = 10,00,000 (no standard deduction for self-employed)
            // 3L–7L: 20,000; 7L–10L: 30,000 → basicTax = 50,000
            // rebate = 0 (taxable > 7L); cess = 2,000; finalTax = 52,000
            let result = calc.calculate(profile: profile(income: 10_00_000, source: .selfEmployed))
            #expect(result.standardDeduction == 0)
            #expect(result.taxableIncome  == 10_00_000)
            #expect(result.basicTax  == 50_000)
            #expect(result.rebate    == 0)
            #expect(result.cess      == 2_000)
            #expect(result.finalTax  == 52_000)
        }

        @Test("custom deductions ignored in new regime")
        func customDeductionsIgnoredNewRegime() {
            let deduction = TaxDeduction(name: "80C", amount: 1_50_000, section: "80C")
            let withDeductions = TaxProfile(
                country: .india,
                annualIncome: 15_00_000,
                indiaRegime: .newRegime,
                customDeductions: [deduction],
                financialYear: "2024-25",
                incomeSourceType: .salaried
            )
            let withoutDeductions = profile(income: 15_00_000)
            let r1 = calc.calculate(profile: withDeductions)
            let r2 = calc.calculate(profile: withoutDeductions)
            #expect(r1.taxableIncome == r2.taxableIncome)
            #expect(r1.finalTax == r2.finalTax)
        }
    }

    // MARK: - India FY 2025-26 New Regime

    @Suite("India FY 2025-26 New Regime")
    struct IndiaFY2025NewRegime {
        let calc = IndiaTaxCalculator()

        private func profile(income: Decimal) -> TaxProfile {
            TaxProfile(
                country: .india,
                annualIncome: income,
                indiaRegime: .newRegime,
                financialYear: "2025-26",
                incomeSourceType: .salaried
            )
        }

        @Test("₹12L salaried – rebate eliminates tax at threshold")
        func twelveLakhZeroTax() {
            // taxable = 12,00,000 − 75,000 = 11,25,000
            // 4L–8L: 4,00,000 × 5% = 20,000; 8L–11.25L: 3,25,000 × 10% = 32,500
            // basicTax = 52,500; rebate = min(52,500, 60,000) = 52,500 → finalTax = 0
            let result = calc.calculate(profile: profile(income: 12_00_000))
            #expect(result.taxableIncome == 11_25_000)
            #expect(result.basicTax  == 52_500)
            #expect(result.rebate    == 52_500)
            #expect(result.finalTax  == 0)
        }

        @Test("₹15L salaried – FY2025 slabs applied")
        func fifteenLakhFY2025Slabs() {
            // taxable = 15,00,000 − 75,000 = 14,25,000
            // 4L–8L: 20,000; 8L–12L: 40,000; 12L–14.25L: 2,25,000 × 15% = 33,750
            // basicTax = 93,750; rebate = 0; cess = 3,750; finalTax = 97,500
            let result = calc.calculate(profile: profile(income: 15_00_000))
            #expect(result.taxableIncome == 14_25_000)
            #expect(result.basicTax  == 93_750)
            #expect(result.rebate    == 0)
            #expect(result.cess      == 3_750)
            #expect(result.finalTax  == 97_500)
        }

        @Test("₹13L salaried – marginal relief reduces tax")
        func thirteenLakhMarginalRelief() {
            // taxable = 13,00,000 − 75,000 = 12,25,000
            // 4L–8L: 20,000; 8L–12L: 40,000; 12L–12.25L: 25,000 × 15% = 3,750
            // basicTax = 63,750; excess = 25,000
            // rebate = max(0, min(63,750, 60,000, 63,750−25,000=38,750)) = 38,750
            // taxAfterRebate = 25,000; cess = 1,000; finalTax = 26,000
            let result = calc.calculate(profile: profile(income: 13_00_000))
            #expect(result.basicTax  == 63_750)
            #expect(result.rebate    == 38_750)
            #expect(result.cess      == 1_000)
            #expect(result.finalTax  == 26_000)
        }
    }

    // MARK: - India Old Regime

    @Suite("India Old Regime")
    struct IndiaOldRegime {
        let calc = IndiaTaxCalculator()

        @Test("₹5L salaried – §87A rebate wipes tax (regular)")
        func fiveLakhRegularZeroTax() {
            // taxable = 5,00,000 − 50,000 = 4,50,000
            // 2.5L–4.5L: 2,00,000 × 5% = 10,000 → basicTax = 10,000
            // rebate = min(10,000, 12,500) = 10,000 → finalTax = 0
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 5_00_000, indiaRegime: .oldRegime,
                financialYear: "2024-25", incomeSourceType: .salaried
            ))
            #expect(result.basicTax  == 10_000)
            #expect(result.rebate    == 10_000)
            #expect(result.finalTax  == 0)
        }

        @Test("₹10L salaried – regular age brackets")
        func tenLakhRegularAge() {
            // taxable = 10,00,000 − 50,000 = 9,50,000
            // 2.5L–5L: 12,500; 5L–9.5L: 4,50,000 × 20% = 90,000 → basicTax = 1,02,500
            // cess = 4,100; finalTax = 1,06,600
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 10_00_000, indiaRegime: .oldRegime,
                financialYear: "2024-25", incomeSourceType: .salaried
            ))
            #expect(result.taxableIncome == 9_50_000)
            #expect(result.basicTax  == 1_02_500)
            #expect(result.rebate    == 0)
            #expect(result.cess      == 4_100)
            #expect(result.finalTax  == 1_06_600)
        }

        @Test("₹10L salaried – senior (60–79) brackets")
        func tenLakhSenior() {
            // senior dob: born 1950, age 74 at FY2024 start
            // taxable = 9,50,000
            // Senior: 3L–5L: 2,00,000 × 5% = 10,000; 5L–9.5L: 90,000 → basicTax = 1,00,000
            // cess = 4,000; finalTax = 1,04,000
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 10_00_000, indiaRegime: .oldRegime,
                financialYear: "2024-25", incomeSourceType: .salaried,
                dateOfBirth: dobFixed(year: 1950)
            ))
            #expect(result.basicTax  == 1_00_000)
            #expect(result.cess      == 4_000)
            #expect(result.finalTax  == 1_04_000)
        }

        @Test("₹10L salaried – super-senior (80+) brackets")
        func tenLakhSuperSenior() {
            // super-senior dob: born 1940, age 84 at FY2024 start
            // taxable = 9,50,000
            // Super-senior: 5L–9.5L: 90,000 → basicTax = 90,000
            // cess = 3,600; finalTax = 93,600
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 10_00_000, indiaRegime: .oldRegime,
                financialYear: "2024-25", incomeSourceType: .salaried,
                dateOfBirth: dobFixed(year: 1940)
            ))
            #expect(result.basicTax  == 90_000)
            #expect(result.cess      == 3_600)
            #expect(result.finalTax  == 93_600)
        }

        @Test("₹10L salaried – custom §80C deduction reduces tax")
        func tenLakhWithCustomDeduction() {
            // taxable = 10,00,000 − 50,000 − 1,50,000 = 8,00,000
            // 2.5L–5L: 12,500; 5L–8L: 3,00,000 × 20% = 60,000 → basicTax = 72,500
            // cess = 2,900; finalTax = 75,400
            let deduction = TaxDeduction(name: "80C", amount: 1_50_000, section: "80C")
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 10_00_000, indiaRegime: .oldRegime,
                customDeductions: [deduction],
                financialYear: "2024-25", incomeSourceType: .salaried
            ))
            #expect(result.taxableIncome      == 8_00_000)
            #expect(result.customDeductionsTotal == 1_50_000)
            #expect(result.basicTax  == 72_500)
            #expect(result.cess      == 2_900)
            #expect(result.finalTax  == 75_400)
        }

        private func dobFixed(year: Int) -> Date {
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        }
    }

    // MARK: - India zero income

    @Test("India – zero income produces zero tax")
    func indiaZeroIncome() {
        let calc = IndiaTaxCalculator()
        for regime in [IndiaRegime.newRegime, .oldRegime] {
            let result = calc.calculate(profile: TaxProfile(
                country: .india, annualIncome: 0, indiaRegime: regime,
                financialYear: "2024-25", incomeSourceType: .salaried
            ))
            #expect(result.finalTax == 0)
            #expect(result.taxableIncome == 0)
        }
    }

    // MARK: - US Federal Tax

    @Suite("US Federal Tax")
    struct USFederalTax {
        let calc = USTaxCalculator()

        private func profile(
            income: Decimal,
            status: USFilingStatus,
            financialYear: String = "2026",
            customDeductions: [TaxDeduction] = []
        ) -> TaxProfile {
            TaxProfile(
                country: .unitedStates,
                annualIncome: income,
                indiaRegime: .newRegime,
                filingStatus: status,
                customDeductions: customDeductions,
                financialYear: financialYear
            )
        }

        @Test("TY2026 Single $50k – standard deduction and two brackets")
        func ty2026SingleFiftyK() {
            // taxable = 50,000 − 16,100 = 33,900
            // 0–12,400: 10% = 1,240; 12,400–33,900: 12% = 2,580 → basicTax = 3,820
            let result = calc.calculate(profile: profile(income: 50_000, status: .single))
            #expect(result.standardDeduction == 16_100)
            #expect(result.taxableIncome == 33_900)
            #expect(result.basicTax  == 3_820)
            #expect(result.finalTax  == 3_820)
            #expect(result.rebate    == 0)
            #expect(result.surcharge == 0)
            #expect(result.cess      == 0)
        }

        @Test("TY2025 Single $50k – different bracket thresholds")
        func ty2025SingleFiftyK() {
            // taxable = 50,000 − 15,750 = 34,250
            // 0–11,925: 10% = 1,192.50; 11,925–34,250: 12% = 2,679.00 → basicTax = 3,871.50
            let result = calc.calculate(profile: profile(income: 50_000, status: .single, financialYear: "2025"))
            #expect(result.standardDeduction == 15_750)
            #expect(result.taxableIncome == 34_250)
            #expect(result.basicTax  == Decimal(string: "3871.5")!)
            #expect(result.finalTax  == Decimal(string: "3871.5")!)
        }

        @Test("TY2026 MFJ $100k – doubled thresholds")
        func ty2026MFJHundredK() {
            // taxable = 100,000 − 32,200 = 67,800
            // 0–24,800: 10% = 2,480; 24,800–67,800: 12% = 5,160 → basicTax = 7,640
            let result = calc.calculate(profile: profile(income: 100_000, status: .marriedFilingJointly))
            #expect(result.standardDeduction == 32_200)
            #expect(result.taxableIncome == 67_800)
            #expect(result.basicTax == 7_640)
            #expect(result.finalTax == 7_640)
        }

        @Test("TY2026 HoH $75k – head of household brackets")
        func ty2026HoHSeventyFiveK() {
            // taxable = 75,000 − 24,150 = 50,850
            // 0–17,700: 10% = 1,770; 17,700–50,850: 12% = 3,978 → basicTax = 5,748
            let result = calc.calculate(profile: profile(income: 75_000, status: .headOfHousehold))
            #expect(result.standardDeduction == 24_150)
            #expect(result.taxableIncome == 50_850)
            #expect(result.basicTax == 5_748)
            #expect(result.finalTax == 5_748)
        }

        @Test("TY2024 Single $50k – legacy brackets apply")
        func ty2024LegacyBrackets() {
            // taxable = 50,000 − 14,600 = 35,400
            // 0–11,600: 10% = 1,160; 11,600–35,400: 12% = 2,856 → basicTax = 4,016
            let result = calc.calculate(profile: profile(income: 50_000, status: .single, financialYear: "2024"))
            #expect(result.standardDeduction == 14_600)
            #expect(result.taxableIncome == 35_400)
            #expect(result.basicTax == 4_016)
        }

        @Test("zero income produces zero tax")
        func zeroIncome() {
            let result = calc.calculate(profile: profile(income: 0, status: .single))
            #expect(result.taxableIncome == 0)
            #expect(result.finalTax == 0)
        }

        @Test("itemized deduction mode overrides standard deduction")
        func itemizedDeductionMode() {
            // itemized = 25,000 > standard (16,100) → taxable = 50,000 − 25,000 = 25,000
            let deduction = TaxDeduction(name: "Mortgage interest", amount: 25_000, section: nil)
            let p = profile(income: 50_000, status: .single, customDeductions: [deduction])
            let result = calc.calculate(profile: p, deductionMode: .itemizedOnly)
            #expect(result.taxableIncome == 25_000)
            #expect(result.customDeductionsTotal == 25_000)
            #expect(result.standardDeduction == 0)
        }

        @Test("standard-only mode ignores itemized even when larger")
        func standardOnlyMode() {
            let deduction = TaxDeduction(name: "Charity", amount: 25_000, section: nil)
            let p = profile(income: 50_000, status: .single, customDeductions: [deduction])
            let result = calc.calculate(profile: p, deductionMode: .standardOnly)
            // TY2026 standard = 16,100; taxable = 50,000 − 16,100 = 33,900
            #expect(result.standardDeduction == 16_100)
            #expect(result.taxableIncome == 33_900)
        }

        @Test("best-available mode picks itemized when larger")
        func bestAvailablePicksItemized() {
            let deduction = TaxDeduction(name: "Business expense", amount: 25_000, section: nil)
            let p = profile(income: 50_000, status: .single, customDeductions: [deduction])
            let result = calc.calculate(profile: p, deductionMode: .bestAvailable)
            #expect(result.taxableIncome == 25_000)
        }

        @Test("best-available mode keeps standard when itemized is smaller")
        func bestAvailableKeepsStandard() {
            let deduction = TaxDeduction(name: "Small donation", amount: 500, section: nil)
            let p = profile(income: 50_000, status: .single, customDeductions: [deduction])
            let result = calc.calculate(profile: p, deductionMode: .bestAvailable)
            // standard (16,100) > itemized (500) → use standard
            #expect(result.standardDeduction == 16_100)
            #expect(result.taxableIncome == 33_900)
        }
    }
}
