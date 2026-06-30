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

    @Test("80D self cap increases for senior citizens")
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
