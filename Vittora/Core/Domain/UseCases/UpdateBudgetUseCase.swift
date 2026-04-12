import Foundation

struct UpdateBudgetUseCase: Sendable {
    let budgetRepository: any BudgetRepository

    /// Update an existing budget.
    func execute(_ entity: BudgetEntity) async throws {
        guard entity.amount > 0 else {
            throw VittoraError.validationFailed("Budget amount must be greater than 0")
        }
        try await budgetRepository.update(entity)
    }
}
