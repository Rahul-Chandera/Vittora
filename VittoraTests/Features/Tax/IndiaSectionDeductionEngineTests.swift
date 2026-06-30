import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("India Section Deduction Engine Tests")
struct IndiaSectionDeductionEngineTests {

    @Test("80C claims are capped at ₹1.5 lakh")
    func caps80C() {
        let deductions = [
            TaxDeduction(name: "PPF", amount: 100_000, section: "80C"),
            TaxDeduction(name: "ELSS", amount: 100_000, section: "80C"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 150_000)
        #expect(result.utilizations.first { $0.sectionKey == "80C" }?.allowed == 150_000)
        #expect(!result.warnings.isEmpty)
    }

    @Test("80CCD(1B) is capped separately at ₹50,000")
    func caps80CCD1B() {
        let deductions = [
            TaxDeduction(name: "NPS", amount: 80_000, section: "80CCD(1B)"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 50_000)
    }

    @Test("80D self cap increases for senior citizens at FY end")
    func caps80DSeniorTier() {
        let dob = Calendar.current.date(from: DateComponents(year: 1960, month: 1, day: 1))
        let deductions = [
            TaxDeduction(name: "Health", amount: 60_000, section: "80D"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: dob,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 50_000)
    }

    @Test("80D senior cap applies when taxpayer turns 60 during the FY")
    func caps80DSeniorWhenTurning60MidFY() {
        // Born 1 Jul 1965 → turns 60 during FY 2025-26; age on 31 Mar 2026 is 60.
        let dob = Calendar.current.date(from: DateComponents(year: 1965, month: 7, day: 1))
        let deductions = [
            TaxDeduction(name: "Health", amount: 45_000, section: "80D"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: dob,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 45_000)
        #expect(result.utilizations.first { $0.sectionKey == "80D" }?.statutoryCap == 50_000)
    }

    @Test("80D regular cap when taxpayer turns 60 after FY end")
    func caps80DRegularWhenTurning60AfterFY() {
        // Born 1 Apr 1966 → still 59 on 31 Mar 2026.
        let dob = Calendar.current.date(from: DateComponents(year: 1966, month: 4, day: 1))
        let deductions = [
            TaxDeduction(name: "Health", amount: 40_000, section: "80D"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: dob,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 25_000)
    }

    @Test("unsupported deduction sections are not applied")
    func rejectsUncappedOtherSections() {
        let deductions = [
            TaxDeduction(name: "Home loan interest", amount: 200_000, section: "24(b)"),
            TaxDeduction(name: "Donation", amount: 50_000, section: "80G"),
        ]

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )

        #expect(result.allowedTotal == 0)
        #expect(result.warnings.contains { $0.localizedCaseInsensitiveContains("Unsupported") })
    }

    @Test("HRA exemption uses minimum of three components")
    func hraMinimumOfThree() {
        let inputs = TaxAdvancedInputs(
            indiaBasicSalary: 600_000,
            indiaHRAPaid: 240_000,
            indiaRentPaid: 300_000,
            indiaMetroCity: true
        )

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: [],
            advancedInputs: inputs,
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )

        // rent - 10% salary = 240k; 50% salary = 300k; HRA = 240k → min = 240k
        #expect(result.hraExemption == 240_000)
        #expect(result.allowedTotal == 240_000)
    }

    @Test("HRA non-metro uses 40% salary component")
    func hraNonMetro() {
        let inputs = TaxAdvancedInputs(
            indiaBasicSalary: 500_000,
            indiaHRAPaid: 300_000,
            indiaRentPaid: 250_000,
            indiaMetroCity: false
        )

        let result = IndiaSectionDeductionEngine.resolve(
            deductions: [],
            advancedInputs: inputs,
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )

        // rent - 10% = 200k; 40% salary = 200k; HRA 300k → 200k
        #expect(result.hraExemption == 200_000)
    }

    @Test("IndiaTaxCalculator applies capped deductions in old regime")
    func calculatorUsesCappedDeductions() {
        let calculator = IndiaTaxCalculator()
        let profile = TaxProfile(
            country: .india,
            annualIncome: 1_000_000,
            indiaRegime: .oldRegime,
            customDeductions: [
                TaxDeduction(name: "PPF", amount: 200_000, section: "80C"),
            ],
            financialYear: "2025-26"
        )

        let estimate = calculator.calculate(profile: profile)
        #expect(estimate.customDeductionsTotal == 150_000)
        #expect(estimate.taxableIncome == 800_000)
    }
}
