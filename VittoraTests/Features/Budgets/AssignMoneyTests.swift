import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Assigning money writes monthly budgets, so what gets created, updated or left alone
/// is what these pin, along with the ready-to-assign arithmetic.
@MainActor
@Suite("Assign Money Tests")
struct AssignMoneyTests {
    private let groceries = CategoryEntity(name: "Groceries", icon: "cart", sortOrder: 0)
    private let dining = CategoryEntity(name: "Dining", icon: "fork.knife", sortOrder: 1)
    private let salary = CategoryEntity(name: "Salary", icon: "briefcase", type: .income)

    @Test("Ready to assign is income less what is assigned; sub-category spending counts for its parent")
    func planArithmetic() {
        let coffee = CategoryEntity(name: "Coffee", icon: "cup.and.saucer", parentID: dining.id)
        let plan = AssignMoneyPlanner.plan(
            transactions: [
                TransactionEntity(amount: 3000, type: .income, categoryID: salary.id),
                TransactionEntity(amount: 120, type: .expense, categoryID: groceries.id),
                TransactionEntity(amount: 8, type: .expense, categoryID: coffee.id),
            ],
            budgets: [BudgetEntity(amount: 500, period: .monthly, categoryID: groceries.id)],
            categories: [groceries, dining, coffee, salary]
        )
        #expect(plan.income == 3000)
        #expect(plan.assigned == 500)
        #expect(plan.readyToAssign == 2500)
        #expect(plan.rows.map(\.name) == ["Groceries", "Dining"])
        #expect(plan.rows[0].available == 380)
        #expect(plan.rows[1].spent == 8)
    }

    @Test("A weekly budget is shown but not counted as assigned or edited here")
    func otherPeriodLeftAlone() {
        let plan = AssignMoneyPlanner.plan(
            transactions: [],
            budgets: [BudgetEntity(amount: 50, period: .weekly, categoryID: dining.id)],
            categories: [groceries, dining]
        )
        #expect(plan.assigned == 0)
        #expect(plan.rows.first { $0.categoryID == dining.id }?.otherPeriod == .weekly)
    }

    @Test("Over-assigning makes ready to assign negative")
    func overAssigned() {
        let plan = AssignMoneyPlanner.plan(
            transactions: [TransactionEntity(amount: 100, type: .income)],
            budgets: [BudgetEntity(amount: 150, period: .monthly, categoryID: groceries.id)],
            categories: [groceries]
        )
        #expect(plan.readyToAssign == -50)
    }

    private func makeViewModel(budgets: [BudgetEntity]) async -> (AssignMoneyViewModel, MockBudgetRepository) {
        let budgetRepository = MockBudgetRepository()
        for budget in budgets { await budgetRepository.seed(budget) }
        let categories = MockCategoryRepository()
        await categories.seedMany([groceries, dining])
        let vm = AssignMoneyViewModel(
            reportingTransactions: MockTransactionRepository(),
            budgetRepository: budgetRepository,
            categoryRepository: categories
        )
        await vm.load()
        return (vm, budgetRepository)
    }

    @Test("Assigning to a category without a budget creates a monthly one that rolls over")
    func assignCreatesMonthlyBudget() async throws {
        let (vm, repository) = await makeViewModel(budgets: [])
        await vm.assign(250, to: groceries.id)
        let created = try #require(await repository.budgets.first)
        #expect(created.categoryID == groceries.id)
        #expect(created.amount == 250)
        #expect(created.period == .monthly)
        #expect(created.rollover)
        #expect(vm.plan?.assigned == 250)
    }

    @Test("Assigning again updates the same monthly budget instead of adding another")
    func assignUpdatesExisting() async throws {
        let existing = BudgetEntity(amount: 100, period: .monthly, categoryID: groceries.id)
        let (vm, repository) = await makeViewModel(budgets: [existing])
        await vm.assign(300, to: groceries.id)
        #expect(await repository.budgets.count == 1)
        #expect(await repository.budgets.first?.amount == 300)
        #expect(await repository.budgets.first?.id == existing.id)
    }

    @Test("A weekly budget is never changed from this screen, and zero is ignored")
    func weeklyAndZeroIgnored() async throws {
        let weekly = BudgetEntity(amount: 50, period: .weekly, categoryID: dining.id)
        let (vm, repository) = await makeViewModel(budgets: [weekly])
        await vm.assign(400, to: dining.id)
        await vm.assign(0, to: groceries.id)
        #expect(await repository.budgets.count == 1)
        #expect(await repository.budgets.first?.amount == 50)
    }
}
