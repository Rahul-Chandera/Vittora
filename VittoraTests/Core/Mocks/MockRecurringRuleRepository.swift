import Foundation
@testable import Vittora

actor MockRecurringRuleRepository: RecurringRuleRepository {
    private(set) var rules: [RecurringRuleEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [RecurringRuleEntity] {
        if shouldThrowError { throw throwError }
        return rules
    }

    func fetchByID(_ id: UUID) async throws -> RecurringRuleEntity? {
        if shouldThrowError { throw throwError }
        return rules.first { $0.id == id }
    }

    func create(_ entity: RecurringRuleEntity) async throws {
        if shouldThrowError { throw throwError }
        rules.append(entity)
    }

    func update(_ entity: RecurringRuleEntity) async throws {
        if shouldThrowError { throw throwError }
        if let index = rules.firstIndex(where: { $0.id == entity.id }) {
            rules[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
    }

    func fetchActive() async throws -> [RecurringRuleEntity] {
        if shouldThrowError { throw throwError }
        return rules.filter { $0.isActive }
    }

    func fetchDueRules(before date: Date) async throws -> [RecurringRuleEntity] {
        if shouldThrowError { throw throwError }
        return rules.filter { $0.isActive && $0.nextDate <= date }
    }

    // MARK: - Test Helpers

    func seed(_ entity: RecurringRuleEntity) {
        rules.append(entity)
    }
}
