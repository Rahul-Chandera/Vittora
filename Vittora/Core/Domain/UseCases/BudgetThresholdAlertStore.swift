import Foundation
import VittoraCore

protocol BudgetThresholdAlertStoring: Sendable {
    func firedLevels(forPeriodKey key: String) -> Set<BudgetThresholdLevel>
    func markFired(_ level: BudgetThresholdLevel, forPeriodKey key: String)
}

enum BudgetThresholdAlertStore {
    nonisolated static func periodKey(for budget: BudgetEntity) -> String {
        "\(budget.id.uuidString)-\(Int(budget.startDate.timeIntervalSince1970))"
    }
}

final class UserDefaultsBudgetThresholdAlertStore: BudgetThresholdAlertStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey = AppUserDefaults.StandardKey.budgetThresholdFired
    nonisolated private let lock = NSLock()

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    nonisolated func firedLevels(forPeriodKey key: String) -> Set<BudgetThresholdLevel> {
        lock.lock()
        defer { lock.unlock() }
        guard let map = userDefaults.dictionary(forKey: storageKey) as? [String: [Int]],
              let rawValues = map[key]
        else {
            return []
        }
        return Set(rawValues.compactMap(BudgetThresholdLevel.init))
    }

    nonisolated func markFired(_ level: BudgetThresholdLevel, forPeriodKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        var map = userDefaults.dictionary(forKey: storageKey) as? [String: [Int]] ?? [:]
        var levels = Set(map[key] ?? [])
        levels.insert(level.rawValue)
        map[key] = levels.sorted()
        userDefaults.set(map, forKey: storageKey)
    }
}

protocol ActiveBudgetFetching: Sendable {
    func fetchActiveBudgetsWithSpent() async throws -> [BudgetEntity]
}

extension FetchBudgetsUseCase: ActiveBudgetFetching {
    func fetchActiveBudgetsWithSpent() async throws -> [BudgetEntity] {
        try await execute()
    }
}
