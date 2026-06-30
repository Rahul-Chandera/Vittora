import Foundation
import VittoraCore

struct ManageCategorizationRulesUseCase: Sendable {
    let ruleStore: any CategorizationRuleStoring
    let categoryRepository: any CategoryRepository

    nonisolated init(
        ruleStore: any CategorizationRuleStoring,
        categoryRepository: any CategoryRepository
    ) {
        self.ruleStore = ruleStore
        self.categoryRepository = categoryRepository
    }

    func fetchAll() async throws -> [CategorizationRule] {
        try ruleStore.fetchAll()
    }

    func save(_ rule: CategorizationRule) async throws {
        let trimmedKeyword = rule.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            throw VittoraError.validationFailed(
                String(localized: "Keyword cannot be empty.")
            )
        }
        guard try await categoryRepository.fetchByID(rule.categoryID) != nil else {
            throw VittoraError.validationFailed(
                String(localized: "Selected category no longer exists.")
            )
        }

        var normalized = rule
        normalized.keyword = trimmedKeyword
        try ruleStore.save(normalized)
    }

    func delete(id: UUID) async throws {
        try ruleStore.delete(id: id)
    }
}
