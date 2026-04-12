import Foundation

struct RolloverBudgetUseCase: Sendable {
    let budgetRepository: any BudgetRepository

    /// Roll over a budget to the next period.
    /// If rollover=true, new amount = original.amount + (original.amount - spent).
    /// If rollover=false, new amount = original.amount.
    /// - Parameters:
    ///   - budgetID: ID of budget to roll over
    ///   - newStartDate: Start date for the new budget period
    func execute(budgetID: UUID, newStartDate: Date) async throws {
        guard let budget = try await budgetRepository.fetchByID(budgetID) else {
            throw VittoraError.notFound("Budget not found")
        }

        let unused = budget.amount - budget.spent
        let newAmount = budget.rollover ? budget.amount + unused : budget.amount

        let newBudget = BudgetEntity(
            amount: newAmount,
            spent: 0,
            period: budget.period,
            startDate: newStartDate,
            rollover: budget.rollover,
            categoryID: budget.categoryID
        )

        try await budgetRepository.create(newBudget)
    }
}
