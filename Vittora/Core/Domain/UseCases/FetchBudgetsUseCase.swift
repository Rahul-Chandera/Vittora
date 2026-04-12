import Foundation

struct FetchBudgetsUseCase: Sendable {
    let budgetRepository: any BudgetRepository
    let transactionRepository: any TransactionRepository

    /// Fetch only active (current period) budgets with calculated spent amounts.
    func execute() async throws -> [BudgetEntity] {
        var budgets = try await budgetRepository.fetchActive()
        for i in 0..<budgets.count {
            budgets[i].spent = try await calculateSpent(for: budgets[i])
        }
        return budgets
    }

    /// Fetch all budgets (including past/inactive) with calculated spent amounts.
    func executeAll() async throws -> [BudgetEntity] {
        var budgets = try await budgetRepository.fetchAll()
        for i in 0..<budgets.count {
            budgets[i].spent = try await calculateSpent(for: budgets[i])
        }
        return budgets
    }

    /// Calculate the amount spent in a budget's current period.
    private func calculateSpent(for budget: BudgetEntity) async throws -> Decimal {
        let dateRange = budget.period.dateRange(startingFrom: budget.startDate)
        let filter = TransactionFilter(
            dateRange: dateRange,
            types: Set([.expense]),
            categoryIDs: budget.categoryID.map { Set([$0]) }
        )
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        return transactions.reduce(0) { $0 + $1.amount }
    }
}

