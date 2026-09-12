import Foundation
import VittoraCore

struct CreateBudgetUseCase: Sendable {
    let budgetRepository: any BudgetRepository

    /// Create a new budget with validation.
    /// - Parameters:
    ///   - amount: Budget amount (must be > 0)
    ///   - period: Budget period (.weekly, .monthly, .quarterly, .yearly)
    ///   - categoryID: Optional category constraint
    ///   - rollover: Whether unused amount rolls to next period
    ///   - startDate: Budget start date
    /// - Throws: VittoraError.validationFailed if validation fails
    func execute(
        amount: Decimal,
        period: BudgetPeriod,
        categoryID: UUID? = nil,
        rollover: Bool = false,
        startDate: Date = .now
    ) async throws {
        // Validate amount
        guard amount > 0 else {
            throw VittoraError.validationFailed("Budget amount must be greater than 0")
        }

        // Two active budgets on one category make a transaction count against both,
        // so the totals stop meaning anything.
        let activeBudgets = try await budgetRepository.fetchActive()
        if activeBudgets.contains(where: { $0.categoryID == categoryID }) {
            let message = categoryID == nil
                ? String(localized: "An overall budget is already running. Edit or delete it before adding another.")
                : String(localized: "A budget for this category is already running. Edit or delete it before adding another.")
            throw VittoraError.validationFailed(message)
        }

        let budget = BudgetEntity(
            amount: amount,
            spent: 0,
            period: period,
            startDate: startDate,
            rollover: rollover,
            categoryID: categoryID
        )

        try await budgetRepository.create(budget)
    }
}
