import Foundation

struct PauseResumeRuleUseCase: Sendable {
    let repository: any RecurringRuleRepository

    init(repository: any RecurringRuleRepository) {
        self.repository = repository
    }

    /// Toggle the active state of a rule
    func execute(id: UUID) async throws {
        guard let rule = try await repository.fetchByID(id) else {
            throw VittoraError.notFound("Recurring rule not found")
        }

        var updatedRule = rule
        updatedRule.isActive.toggle()
        updatedRule.updatedAt = .now
        try await repository.update(updatedRule)
    }

    /// Pause a rule (set isActive = false)
    func pause(id: UUID) async throws {
        guard let rule = try await repository.fetchByID(id) else {
            throw VittoraError.notFound("Recurring rule not found")
        }

        var updatedRule = rule
        updatedRule.isActive = false
        updatedRule.updatedAt = .now
        try await repository.update(updatedRule)
    }

    /// Resume a rule (set isActive = true)
    func resume(id: UUID) async throws {
        guard let rule = try await repository.fetchByID(id) else {
            throw VittoraError.notFound("Recurring rule not found")
        }

        var updatedRule = rule
        updatedRule.isActive = true
        updatedRule.updatedAt = .now
        try await repository.update(updatedRule)
    }
}
