import Foundation
import VittoraCore

protocol SpendingInsightDismissalStoring: Sendable {
    func isDismissed(insightID: String, period: String) -> Bool
    func dismiss(insightID: String, period: String)
    func resetAll()
}

/// Persists insight dismissal per insight per period.
///
/// Per period, not once and for all: dining doubling in September is worth saying again if
/// it doubles in October. The compliance tips make the same choice against the financial
/// year — dismissing a tip is "not now", not "never tell me".
final class UserDefaultsSpendingInsightDismissalStore: SpendingInsightDismissalStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey: String
    nonisolated private let lock = NSLock()

    nonisolated init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = AppUserDefaults.StandardKey.spendingInsightDismissals
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    nonisolated func isDismissed(insightID: String, period: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let map = userDefaults.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
        return map[Self.key(insightID: insightID, period: period)] == true
    }

    nonisolated func dismiss(insightID: String, period: String) {
        lock.lock()
        defer { lock.unlock() }
        var map = userDefaults.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
        map[Self.key(insightID: insightID, period: period)] = true
        userDefaults.set(map, forKey: storageKey)
    }

    nonisolated func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: storageKey)
    }

    nonisolated static func key(insightID: String, period: String) -> String {
        "\(insightID)|\(period)"
    }
}
