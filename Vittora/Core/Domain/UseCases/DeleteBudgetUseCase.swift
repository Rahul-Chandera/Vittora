import Foundation

struct DeleteBudgetUseCase: Sendable {
    let budgetRepository: any BudgetRepository

    /// Delete a budget by ID.
    func execute(id: UUID) async throws {
        try await budgetRepository.delete(id)
    }
}
