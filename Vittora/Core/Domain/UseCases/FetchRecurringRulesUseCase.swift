import Foundation

struct FetchRecurringRulesUseCase: Sendable {
    let repository: any RecurringRuleRepository

    init(repository: any RecurringRuleRepository) {
        self.repository = repository
    }

    /// Fetch all recurring rules, sorted by nextDate (ascending)
    func execute() async throws -> [RecurringRuleEntity] {
        let rules = try await repository.fetchAll()
        return rules.sorted { $0.nextDate < $1.nextDate }
    }

    /// Fetch only active recurring rules, sorted by nextDate
    func executeActive() async throws -> [RecurringRuleEntity] {
        let rules = try await repository.fetchActive()
        return rules.sorted { $0.nextDate < $1.nextDate }
    }

    /// Fetch rules due within the next N days
    func executeDueSoon(within days: Int) async throws -> [RecurringRuleEntity] {
        let futureDate = Date.now.addingTimeInterval(TimeInterval(days * 86400))
        let dueRules = try await repository.fetchDueRules(before: futureDate)
        return dueRules.sorted { $0.nextDate < $1.nextDate }
    }
}
