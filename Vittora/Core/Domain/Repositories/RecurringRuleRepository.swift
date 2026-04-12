import Foundation

protocol RecurringRuleRepository: Sendable {
    func fetchAll() async throws -> [RecurringRuleEntity]
    func fetchByID(_ id: UUID) async throws -> RecurringRuleEntity?
    func create(_ entity: RecurringRuleEntity) async throws
    func update(_ entity: RecurringRuleEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchActive() async throws -> [RecurringRuleEntity]
    func fetchDueRules(before date: Date) async throws -> [RecurringRuleEntity]
}
