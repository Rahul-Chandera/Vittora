import Foundation
import SwiftData

/// Read-only spending/budget queries for WidgetKit (and future App Intents).
/// Opens the App Group store without migrations, writes, or CloudKit.
public struct WidgetDataProvider: Sendable {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    /// Opens the shared on-disk store read-only for extension processes.
    public static func makeSharedReadOnly() throws -> WidgetDataProvider {
        WidgetDataProvider(container: try ModelContainerConfig.makeReadOnlyContainer())
    }

    /// Today's expense total, matching Dashboard's definition.
    public func todaySpending() async throws -> (amount: Decimal, currencyCode: String) {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let now = Date.now
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let filter = TransactionFilter(dateRange: startOfToday...now, types: Set([.expense]))
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        let amount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        return (amount, CurrencyDefaults.code)
    }

    /// Active budgets' spent/total for the current period, matching Dashboard.
    public func budgetSnapshot() async throws -> (spent: Decimal, total: Decimal, currencyCode: String) {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: container)
        let budgets = try await budgetRepository.fetchActive()

        var totalSpent: Decimal = 0
        var totalBudget: Decimal = 0
        for budget in budgets {
            totalBudget += budget.amount
            totalSpent += try await spent(for: budget, transactionRepository: transactionRepository)
        }
        return (totalSpent, totalBudget, CurrencyDefaults.code)
    }

    /// Same period/category filtering as `FetchBudgetsUseCase` in the app target.
    private func spent(
        for budget: BudgetEntity,
        transactionRepository: SwiftDataTransactionRepository
    ) async throws -> Decimal {
        let dateRange = budget.period.dateRange(startingFrom: budget.startDate)
        let filter = TransactionFilter(
            dateRange: dateRange,
            types: Set([.expense]),
            categoryIDs: budget.categoryID.map { Set([$0]) }
        )
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        return transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }
}
