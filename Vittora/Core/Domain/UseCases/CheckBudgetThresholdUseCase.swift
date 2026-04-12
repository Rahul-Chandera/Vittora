import Foundation

struct CheckBudgetThresholdUseCase: Sendable {
    /// Return budgets that are at 50%, 75%, 90%, or 100%+ of their budget.
    /// Caller handles notifications.
    func execute(budgets: [BudgetEntity]) -> [BudgetEntity] {
        budgets.filter { budget in
            let progress = budget.progress
            // At or over 50%
            return progress >= 0.5
        }
    }
}
