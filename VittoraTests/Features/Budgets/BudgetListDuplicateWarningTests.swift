import Foundation
import Testing
import VittoraCore

@testable import Vittora

@Suite("Budget list duplicate warning")
@MainActor
struct BudgetListDuplicateWarningTests {

    private func makeViewModel(
        budgetRepository: MockBudgetRepository,
        transactionRepository: MockTransactionRepository = MockTransactionRepository(),
        categoryRepository: MockCategoryRepository
    ) -> BudgetListViewModel {
        BudgetListViewModel(
            fetchUseCase: FetchBudgetsUseCase(
                budgetRepository: budgetRepository,
                transactionRepository: transactionRepository
            ),
            deleteUseCase: DeleteBudgetUseCase(budgetRepository: budgetRepository),
            calculateProgressUseCase: CalculateBudgetProgressUseCase(),
            categoryRepository: categoryRepository
        )
    }

    private var monthStart: Date {
        Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        ) ?? .now
    }

    @Test("two active monthly budgets on the same category leave a warning naming the category")
    func warningWhenTwoBudgetsShareCategory() async throws {
        let budgetRepository = MockBudgetRepository()
        let categoryRepository = MockCategoryRepository()

        let category = CategoryEntity(
            name: "Groceries",
            icon: "cart",
            colorHex: "#34C759",
            type: .expense
        )
        try await categoryRepository.create(category)

        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "400")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: category.id
            )
        )
        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "200")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: category.id
            )
        )

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            categoryRepository: categoryRepository
        )
        await vm.loadBudgets()

        #expect(vm.duplicateCategoryWarning != nil)
        #expect(vm.duplicateCategoryWarning?.contains("Groceries") == true)
    }

    @Test("one budget per category leaves no duplicate warning")
    func noWarningWhenOneBudgetPerCategory() async throws {
        let budgetRepository = MockBudgetRepository()
        let categoryRepository = MockCategoryRepository()

        let groceries = CategoryEntity(
            name: "Groceries", icon: "cart", colorHex: "#34C759", type: .expense
        )
        let dining = CategoryEntity(
            name: "Dining", icon: "fork.knife", colorHex: "#FF6B35", type: .expense
        )
        try await categoryRepository.create(groceries)
        try await categoryRepository.create(dining)

        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "400")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: groceries.id
            )
        )
        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "200")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: dining.id
            )
        )

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            categoryRepository: categoryRepository
        )
        await vm.loadBudgets()

        #expect(vm.duplicateCategoryWarning == nil)
    }

    @Test("two overall budgets with nil category leave a warning")
    func warningWhenTwoOverallBudgets() async throws {
        let budgetRepository = MockBudgetRepository()
        let categoryRepository = MockCategoryRepository()

        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "1000")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: nil
            )
        )
        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "500")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: nil
            )
        )

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            categoryRepository: categoryRepository
        )
        await vm.loadBudgets()

        #expect(vm.duplicateCategoryWarning != nil)
    }

    @Test("warning spans all active periods, not just the selected one")
    func warningComputedAcrossAllActiveBudgets() async throws {
        let budgetRepository = MockBudgetRepository()
        let categoryRepository = MockCategoryRepository()

        let category = CategoryEntity(
            name: "Transport",
            icon: "car",
            colorHex: "#007AFF",
            type: .expense
        )
        try await categoryRepository.create(category)

        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "300")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: category.id
            )
        )
        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "80")!,
                period: .weekly,
                startDate: monthStart,
                categoryID: category.id
            )
        )

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            categoryRepository: categoryRepository
        )
        vm.selectedPeriod = .monthly
        await vm.loadBudgets()

        #expect(vm.budgets.count == 1)
        #expect(vm.duplicateCategoryWarning != nil)
    }
}
