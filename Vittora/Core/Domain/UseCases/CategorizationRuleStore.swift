import Foundation
import VittoraCore

protocol CategorizationRuleStoring: Sendable {
    func fetchAll() throws -> [CategorizationRule]
    func save(_ rule: CategorizationRule) throws
    func delete(id: UUID) throws
}

enum CategorizationRuleStore {
    nonisolated static func clearAll(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: AppUserDefaults.StandardKey.categorizationRules)
    }
}

final class UserDefaultsCategorizationRuleStore: CategorizationRuleStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey = AppUserDefaults.StandardKey.categorizationRules
    nonisolated private let lock = NSLock()

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    nonisolated func fetchAll() throws -> [CategorizationRule] {
        lock.lock()
        defer { lock.unlock() }
        return try decodeRulesLocked()
    }

    nonisolated func save(_ rule: CategorizationRule) throws {
        lock.lock()
        defer { lock.unlock() }
        var rules = try decodeRulesLocked()
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        try encodeRulesLocked(rules)
    }

    nonisolated func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        var rules = try decodeRulesLocked()
        rules.removeAll { $0.id == id }
        try encodeRulesLocked(rules)
    }

    nonisolated private func decodeRulesLocked() throws -> [CategorizationRule] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CategorizationRule].self, from: data)
    }

    nonisolated private func encodeRulesLocked(_ rules: [CategorizationRule]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(rules)
        userDefaults.set(data, forKey: storageKey)
    }
}
