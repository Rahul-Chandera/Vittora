import Foundation
import Testing
import SwiftData
import VittoraCore

@Suite("WidgetDataProvider")
struct WidgetDataProviderTests {

    private func makeProvider() throws -> (WidgetDataProvider, ModelContainer) {
        let container = try ModelContainerConfig.makePreviewContainer()
        return (WidgetDataProvider(container: container), container)
    }

    @Test("todaySpending sums today's expenses only")
    func todaySpendingMatchesSeededExpenses() async throws {
        let (provider, container) = try makeProvider()
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)

        let todayExpense = TransactionEntity(amount: 42.5, date: .now, type: .expense)
        let todayIncome = TransactionEntity(amount: 100, date: .now, type: .income)
        let yesterdayExpense = TransactionEntity(
            amount: 99,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            type: .expense
        )

        try await transactionRepo.create(todayExpense)
        try await transactionRepo.create(todayIncome)
        try await transactionRepo.create(yesterdayExpense)

        let result = try await provider.todaySpending()

        #expect(result.amount == Decimal(425) / 10)
        #expect(result.currencyCode == CurrencyDefaults.code)
    }

    @Test("budgetSnapshot totals active budget amounts and computed spend")
    func budgetSnapshotMatchesSeededBudgets() async throws {
        let (provider, container) = try makeProvider()
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepo = SwiftDataBudgetRepository(modelContainer: container)

        let categoryID = UUID()
        let budget = BudgetEntity(
            amount: 1000,
            period: .monthly,
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            categoryID: categoryID
        )
        try await budgetRepo.create(budget)

        let expense = TransactionEntity(
            amount: 250,
            date: .now,
            type: .expense,
            categoryID: categoryID
        )
        try await transactionRepo.create(expense)

        let snapshot = try await provider.budgetSnapshot()

        #expect(snapshot.spent == 250)
        #expect(snapshot.total == 1000)
        #expect(snapshot.currencyCode == CurrencyDefaults.code)
    }

    @Test("empty store returns zero spending and budget totals")
    func emptyStoreReturnsZeros() async throws {
        let (provider, _) = try makeProvider()

        let spending = try await provider.todaySpending()
        let snapshot = try await provider.budgetSnapshot()

        #expect(spending.amount == 0)
        #expect(snapshot.spent == 0)
        #expect(snapshot.total == 0)
    }
}
