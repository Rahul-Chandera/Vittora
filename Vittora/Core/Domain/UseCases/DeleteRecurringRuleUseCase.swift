import Foundation

struct DeleteRecurringRuleUseCase: Sendable {
    let repository: any RecurringRuleRepository

    init(repository: any RecurringRuleRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws {
        try await repository.delete(id)
    }
}
