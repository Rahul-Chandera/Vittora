import Foundation

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

        // Check for existing active budget with same category and period
        if let categoryID = categoryID {
            if try await budgetRepository.fetchForCategory(categoryID, period: period) != nil {
                throw VittoraError.validationFailed(
                    "An active \(period.rawValue) budget already exists for this category"
                )
            }
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
