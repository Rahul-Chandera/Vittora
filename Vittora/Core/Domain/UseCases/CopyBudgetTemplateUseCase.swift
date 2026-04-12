import Foundation

struct CopyBudgetTemplateUseCase: Sendable {
    let budgetRepository: any BudgetRepository

    /// Copy budgets from one period to another with matching period type.
    /// - Parameters:
    ///   - fromPeriodStart: Start date of source period
    ///   - toPeriodStart: Start date of target period
    ///   - period: Period type to match
    func execute(
        fromPeriodStart: Date,
        toPeriodStart: Date,
        period: BudgetPeriod
    ) async throws {
        // Fetch budgets that started in the source period with matching period type
        let sourceDateRange = period.dateRange(startingFrom: fromPeriodStart)
        let allBudgets = try await budgetRepository.fetchAll()

        let budgetsToClone = allBudgets.filter { budget in
            budget.period == period &&
            budget.startDate >= sourceDateRange.lowerBound &&
            budget.startDate <= sourceDateRange.upperBound
        }

        // Create copies for the target period
        for sourceBudget in budgetsToClone {
            let newBudget = BudgetEntity(
                amount: sourceBudget.amount,
                spent: 0,
                period: sourceBudget.period,
                startDate: toPeriodStart,
                rollover: sourceBudget.rollover,
                categoryID: sourceBudget.categoryID
            )
            try await budgetRepository.create(newBudget)
        }
    }
}
