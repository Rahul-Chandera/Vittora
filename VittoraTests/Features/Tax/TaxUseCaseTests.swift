import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Tax Use Case Tests")
struct TaxUseCaseTests {

    @MainActor
    @Suite("IndiaTaxCalculator")
    struct IndiaTaxCalculatorTests {
        @Test("New regime rebate can reduce tax to zero at the FY 2025-26 threshold")
        func newRegimeRebateScenario() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 1_275_000,
                indiaRegime: .newRegime,
                financialYear: "2025-26"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 75_000)
            #expect(estimate.taxableIncome == 1_200_000)
            #expect(estimate.rebate > 0)
            #expect(estimate.finalTax == 0)
        }

        @Test("New regime marginal relief tapers the FY 2025-26 rebate above 12 lakh")
        func newRegimeMarginalReliefScenario() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 1_285_000,
                indiaRegime: .newRegime,
                financialYear: "2025-26"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.taxableIncome == 1_210_000)
            #expect(estimate.rebate == 51_500)
            #expect(estimate.finalTax == 10_400)
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
                financialYear: "2025-26"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 50_000)
            #expect(estimate.customDeductionsTotal == 175_000)
            #expect(estimate.taxableIncome == 975_000)
            #expect(estimate.finalTax > 0)
        }

        @Test("Old regime §87A rebate eliminates tax at the 5 lakh threshold")
        func oldRegimeRebateAtThreshold() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 500_000,
                indiaRegime: .oldRegime,
                incomeSourceType: .nonSalaried,
                financialYear: "2024-25"
            )
            let estimate = calculator.calculate(profile: profile)
            #expect(estimate.taxableIncome == 500_000)
            #expect(estimate.rebate == 12_500)
            #expect(estimate.finalTax == 0)
        }

        @Test("Old regime §87A marginal relief caps tax at the excess above 5 lakh")
        func oldRegimeMarginalRelief() {
            let calculator = IndiaTaxCalculator()
            let profile = TaxProfile(
                country: .india,
                annualIncome: 510_000,
                indiaRegime: .oldRegime,
                incomeSourceType: .nonSalaried,
                financialYear: "2024-25"
            )
            let estimate = calculator.calculate(profile: profile)
            // Basic tax on ₹5.1L: 5% × 2.5L = 12,500 + 20% × 10,000 = 2,000 → 14,500
            // Marginal relief: rebate = min(14500, 12500, 14500 − 10000) = 4500
            // taxAfterRebate = 14500 − 4500 = 10000 = excess (₹10,000 above threshold)
            #expect(estimate.rebate == 4_500)
            #expect(estimate.finalTax == 10_400) // 10000 × 4% cess = 400
        }
    }

    @MainActor
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
                financialYear: "2026"
            )

            let standardEstimate = calculator.calculate(profile: profile, deductionMode: .standardOnly)
            let itemizedEstimate = calculator.calculate(profile: profile, deductionMode: .itemizedOnly)

            #expect(standardEstimate.standardDeduction == 16_100)
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
                financialYear: "2026"
            )

            let estimate = calculator.calculate(profile: profile)

            #expect(estimate.standardDeduction == 0)
            #expect(estimate.customDeductionsTotal == 20_000)
            #expect(estimate.taxableIncome == 80_000)
        }

        @Test("Qualifying surviving spouse uses joint rules")
        func qualifyingSurvivingSpouseUsesJointRules() {
            let calculator = USTaxCalculator()
            let survivingSpouseProfile = TaxProfile(
                country: .unitedStates,
                annualIncome: 180_000,
                filingStatus: .qualifyingSurvivingSpouse,
                financialYear: "2026"
            )
            let jointProfile = TaxProfile(
                country: .unitedStates,
                annualIncome: 180_000,
                filingStatus: .marriedFilingJointly,
                financialYear: "2026"
            )

            let survivingSpouseEstimate = calculator.calculate(profile: survivingSpouseProfile)
            let jointEstimate = calculator.calculate(profile: jointProfile)

            #expect(survivingSpouseEstimate.standardDeduction == 32_200)
            #expect(survivingSpouseEstimate.finalTax == jointEstimate.finalTax)
        }
    }

    @MainActor
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
                financialYear: "2025-26"
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
                financialYear: "2026"
            )

            let comparison = useCase.execute(profile: profile)

            #expect(comparison.kind == .usDeductionModes)
            #expect(comparison.firstEstimate.standardDeduction > 0)
            #expect(comparison.secondEstimate.customDeductionsTotal == 27_000)
            #expect(comparison.savingsAmount > 0)
        }
    }

    @MainActor
    @Suite("FetchTaxCategoriesUseCase")
    struct FetchTaxCategoriesUseCaseTests {
        @Test("Expense categories with deduction-like names are returned")
        func findsTaxRelevantExpenseCategories() async throws {
            let repo = MockCategoryRepository()
            await repo.seedMany([
                CategoryEntity(name: "Health", icon: "heart.fill", type: .expense, sortOrder: 1),
                CategoryEntity(name: "Education", icon: "book.fill", type: .expense, sortOrder: 2),
                CategoryEntity(name: "Groceries", icon: "cart.fill", type: .expense, sortOrder: 3),
                CategoryEntity(name: "Salary", icon: "briefcase.fill", type: .income, sortOrder: 4),
            ])

            let useCase = FetchTaxCategoriesUseCase(repository: repo)
            let categories = try await useCase.execute(country: .india)

            #expect(categories.map(\.name) == ["Health", "Education"])
        }
    }

    @MainActor
    @Suite("GenerateTaxSummaryUseCase")
    struct GenerateTaxSummaryUseCaseTests {
        @Test("India summary uses April to March financial year and matched categories")
        func indiaSummaryRespectsFinancialYearBoundaries() async throws {
            let categoryRepo = MockCategoryRepository()
            let transactionRepo = MockTransactionRepository()

            let health = CategoryEntity(name: "Health", icon: "heart.fill", type: .expense, sortOrder: 1)
            let groceries = CategoryEntity(name: "Groceries", icon: "cart.fill", type: .expense, sortOrder: 2)
            await categoryRepo.seedMany([health, groceries])

            try await transactionRepo.create(TransactionEntity(
                amount: 12_000,
                date: makeDate(year: 2024, month: 4, day: 10),
                type: .expense,
                categoryID: health.id
            ))
            try await transactionRepo.create(TransactionEntity(
                amount: 8_000,
                date: makeDate(year: 2025, month: 3, day: 25),
                type: .expense,
                categoryID: health.id
            ))
            try await transactionRepo.create(TransactionEntity(
                amount: 6_000,
                date: makeDate(year: 2025, month: 4, day: 1),
                type: .expense,
                categoryID: health.id
            ))
            try await transactionRepo.create(TransactionEntity(
                amount: 5_000,
                date: makeDate(year: 2024, month: 6, day: 1),
                type: .expense,
                categoryID: groceries.id
            ))

            let useCase = GenerateTaxSummaryUseCase(
                transactionRepository: transactionRepo,
                fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase(repository: categoryRepo)
            )

            let summary = try await useCase.execute(profile: TaxProfile(
                country: .india,
                annualIncome: 1_000_000,
                financialYear: "2024-25"
            ))

            #expect(summary.totalRelevantAmount == 20_000)
            #expect(summary.transactionCount == 2)
            #expect(summary.matchedCategoryCount == 1)
            #expect(summary.categoryBreakdown.first?.category.name == "Health")
        }

        @Test("US summary uses the calendar year")
        func usSummaryRespectsCalendarYear() async throws {
            let categoryRepo = MockCategoryRepository()
            let transactionRepo = MockTransactionRepository()

            let charity = CategoryEntity(name: "Charity", icon: "heart.circle.fill", type: .expense, sortOrder: 1)
            await categoryRepo.seed(charity)

            try await transactionRepo.create(TransactionEntity(
                amount: 3_500,
                date: makeDate(year: 2024, month: 2, day: 5),
                type: .expense,
                categoryID: charity.id
            ))
            try await transactionRepo.create(TransactionEntity(
                amount: 1_200,
                date: makeDate(year: 2025, month: 1, day: 3),
                type: .expense,
                categoryID: charity.id
            ))

            let useCase = GenerateTaxSummaryUseCase(
                transactionRepository: transactionRepo,
                fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase(repository: categoryRepo)
            )

            let summary = try await useCase.execute(profile: TaxProfile(
                country: .unitedStates,
                annualIncome: 120_000,
                financialYear: "2024"
            ))

            #expect(summary.totalRelevantAmount == 3_500)
            #expect(summary.transactionCount == 1)
            #expect(summary.categoryBreakdown.first?.category.name == "Charity")
        }
    }
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}
