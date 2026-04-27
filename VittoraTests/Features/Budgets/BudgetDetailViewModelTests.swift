import Foundation
import Testing
@testable import Vittora

@Suite("BudgetDetailViewModel Tests")
@MainActor
struct BudgetDetailViewModelTests {

    private func makeViewModel(
        budgetRepo: MockBudgetRepository,
        categoryRepo: MockCategoryRepository = MockCategoryRepository(),
        txRepo: MockTransactionRepository = MockTransactionRepository()
    ) -> BudgetDetailViewModel {
        BudgetDetailViewModel(
            budgetRepository: budgetRepo,
            categoryRepository: categoryRepo,
            transactionRepository: txRepo,
            calculateProgressUseCase: CalculateBudgetProgressUseCase()
        )
    }

    // MARK: - Initial state

    @Test("starts with nil budget and no error")
    func initialState() {
        let vm = makeViewModel(budgetRepo: MockBudgetRepository())
        #expect(vm.budget == nil)
        #expect(vm.progress == nil)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(vm.recentTransactions.isEmpty)
    }

    // MARK: - loadBudget

    @Test("loadBudget populates budget on success")
    func loadBudgetPopulates() async {
        let budgetRepo = MockBudgetRepository()
        let budget = BudgetEntity(amount: 500, period: .monthly)
        await budgetRepo.seed(budget)

        let vm = makeViewModel(budgetRepo: budgetRepo)
        await vm.loadBudget(id: budget.id)

        #expect(vm.budget?.id == budget.id)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadBudget sets error when budget not found")
    func loadBudgetNotFound() async {
        let budgetRepo = MockBudgetRepository()
        let vm = makeViewModel(budgetRepo: budgetRepo)

        await vm.loadBudget(id: UUID())

        #expect(vm.budget == nil)
        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadBudget sets error on repository failure")
    func loadBudgetRepoError() async {
        let budgetRepo = MockBudgetRepository()
        await budgetRepo.setShouldThrow(true)
        let vm = makeViewModel(budgetRepo: budgetRepo)

        await vm.loadBudget(id: UUID())

        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadBudget computes spent from expense transactions")
    func loadBudgetComputesSpent() async {
        let budgetRepo = MockBudgetRepository()
        let txRepo = MockTransactionRepository()
        let now = Date()
        let budget = BudgetEntity(amount: 500, startDate: now.addingTimeInterval(-3600))
        await budgetRepo.seed(budget)
        await txRepo.seed(TransactionEntity(amount: 100, date: now, type: .expense))
        await txRepo.seed(TransactionEntity(amount: 200, date: now, type: .expense))

        let vm = makeViewModel(budgetRepo: budgetRepo, txRepo: txRepo)
        await vm.loadBudget(id: budget.id)

        #expect(vm.budget?.spent == 300)
    }

    @Test("loadBudget limits recentTransactions to 5")
    func loadBudgetLimitsRecent() async {
        let budgetRepo = MockBudgetRepository()
        let txRepo = MockTransactionRepository()
        let now = Date()
        let budget = BudgetEntity(amount: 1000, startDate: now.addingTimeInterval(-3600))
        await budgetRepo.seed(budget)
        for _ in 0..<7 {
            await txRepo.seed(TransactionEntity(amount: 10, date: now, type: .expense))
        }

        let vm = makeViewModel(budgetRepo: budgetRepo, txRepo: txRepo)
        await vm.loadBudget(id: budget.id)

        #expect(vm.recentTransactions.count <= 5)
    }

    @Test("loadBudget populates category when categoryID is set")
    func loadBudgetPopulatesCategory() async {
        let budgetRepo = MockBudgetRepository()
        let categoryRepo = MockCategoryRepository()

        let category = CategoryEntity(name: "Food", icon: "fork.knife", colorHex: "#FF0000")
        await categoryRepo.seed(category)

        let budget = BudgetEntity(amount: 300, categoryID: category.id)
        await budgetRepo.seed(budget)

        let vm = makeViewModel(budgetRepo: budgetRepo, categoryRepo: categoryRepo)
        await vm.loadBudget(id: budget.id)

        #expect(vm.category?.id == category.id)
    }

    @Test("loadBudget populates progress after loading")
    func loadBudgetPopulatesProgress() async {
        let budgetRepo = MockBudgetRepository()
        let budget = BudgetEntity(amount: 500, spent: 0)
        await budgetRepo.seed(budget)

        let vm = makeViewModel(budgetRepo: budgetRepo)
        await vm.loadBudget(id: budget.id)

        #expect(vm.progress != nil)
    }
}

// MARK: - Actor helpers

extension MockBudgetRepository {
    func setShouldThrow(_ value: Bool) {
        shouldThrowError = value
    }
}
