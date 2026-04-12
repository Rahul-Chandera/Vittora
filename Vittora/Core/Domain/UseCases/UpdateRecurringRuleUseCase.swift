import Foundation

struct UpdateRecurringRuleUseCase: Sendable {
    let repository: any RecurringRuleRepository

    init(repository: any RecurringRuleRepository) {
        self.repository = repository
    }

    func execute(_ entity: RecurringRuleEntity) async throws {
        var updatedEntity = entity
        updatedEntity.updatedAt = .now
        try await repository.update(updatedEntity)
    }
}
