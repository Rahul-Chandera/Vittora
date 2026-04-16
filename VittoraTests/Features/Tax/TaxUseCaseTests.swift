import Foundation
import Testing

@testable import Vittora

@Suite("Tax Use Case Tests")
struct TaxUseCaseTests {

    @Suite("IndiaTaxCalculator")
    struct IndiaTaxCalculatorTests {
        @Test("New regime rebate can reduce tax to zero for lower taxable income")
        func newRegimeRebateScenario() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 700_000,
                indiaRegime: .newRegime,
                financialYear: "2024-25"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 75_000)
            #expect(estimate.taxableIncome == 625_000)
            #expect(estimate.rebate > 0)
            #expect(estimate.finalTax == 0)
        }

        @Test("Old regime applies custom deductions")
        func oldRegimeUsesCustomDeductions() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 1_200_000,
                indiaRegime: .oldRegime,
                customDeductions: [
                    TaxDeduction(name: "PPF", amount: 150_000, section: "80C"),
                    TaxDeduction(name: "Health Insurance", amount: 25_000, section: "80D"),
                ],
                financialYear: "2024-25"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 50_000)
            #expect(estimate.customDeductionsTotal == 175_000)
            #expect(estimate.taxableIncome == 975_000)
            #expect(estimate.finalTax > 0)
        }
    }

    @Suite("USTaxCalculator")
    struct USTaxCalculatorTests {
        @Test("Itemized mode uses custom deductions even when lower than standard")
        func itemizedModeForcesItemizedDeductions() {
            let calculator = USTaxCalculator()
            let profile = TaxProfile(
                country: .unitedStates,
                annualIncome: 100_000,
                filingStatus: .single,
                customDeductions: [
                    TaxDeduction(name: "Mortgage Interest", amount: 10_000),
                ],
                financialYear: "2024"
            )

            let standardEstimate = calculator.calculate(profile: profile, deductionMode: .standardOnly)
            let itemizedEstimate = calculator.calculate(profile: profile, deductionMode: .itemizedOnly)

            #expect(standardEstimate.standardDeduction == 14_600)
            #expect(standardEstimate.customDeductionsTotal == 0)
            #expect(itemizedEstimate.standardDeduction == 0)
            #expect(itemizedEstimate.customDeductionsTotal == 10_000)
            #expect(itemizedEstimate.finalTax > standardEstimate.finalTax)
        }

        @Test("Best available mode prefers larger itemized deduction")
        func bestAvailablePrefersLargerItemizedDeduction() {
            let calculator = USTaxCalculator()
            let profile = TaxProfile(
                country: .unitedStates,
                annualIncome: 100_000,
                filingStatus: .single,
                customDeductions: [
                    TaxDeduction(name: "Mortgage Interest", amount: 20_000),
                ],
                financialYear: "2024"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 0)
            #expect(estimate.customDeductionsTotal == 20_000)
            #expect(estimate.taxableIncome == 80_000)
        }
    }

    @Suite("CompareTaxRegimesUseCase")
    struct CompareTaxRegimesUseCaseTests {
        @Test("India comparison evaluates old and new regimes side by side")
        func indiaComparisonUsesBothRegimes() {
            let useCase = CompareTaxRegimesUseCase()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 1_800_000,
                indiaRegime: .newRegime,
                customDeductions: [
                    TaxDeduction(name: "PPF", amount: 150_000, section: "80C"),
                ],
                financialYear: "2024-25"
            )

            let comparison = useCase.execute(profile: profile)

            #expect(comparison.kind == .indiaRegimes)
            #expect(comparison.firstEstimate.regimeLabel == IndiaRegime.oldRegime.displayName)
            #expect(comparison.secondEstimate.regimeLabel == IndiaRegime.newRegime.displayName)
            #expect(comparison.savingsAmount >= 0)
        }

        @Test("US comparison evaluates standard and itemized deductions")
        func usComparisonUsesDeductionModes() {
            let useCase = CompareTaxRegimesUseCase()
            let profile = TaxProfile(
                country: .unitedStates,
                annualIncome: 120_000,
                filingStatus: .single,
                customDeductions: [
                    TaxDeduction(name: "Mortgage Interest", amount: 22_000),
                    TaxDeduction(name: "Charity", amount: 5_000),
                ],
                financialYear: "2024"
            )

            let comparison = useCase.execute(profile: profile)

            #expect(comparison.kind == .usDeductionModes)
            #expect(comparison.firstEstimate.standardDeduction > 0)
            #expect(comparison.secondEstimate.customDeductionsTotal == 27_000)
            #expect(comparison.savingsAmount > 0)
        }
    }
}
