import Foundation
import VittoraCore

protocol IndiaComplianceTipDismissalStoring: Sendable {
    func isDismissed(ruleID: IndiaComplianceRuleID, financialYear: String) -> Bool
    func dismiss(ruleID: IndiaComplianceRuleID, financialYear: String)
    func resetAll()
}

/// Persists tip dismissal per rule per financial year. A new FY starts with no dismissals.
final class UserDefaultsIndiaComplianceTipDismissalStore: IndiaComplianceTipDismissalStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey: String
    nonisolated private let lock = NSLock()

    nonisolated init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = AppUserDefaults.StandardKey.indiaComplianceTipDismissals
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    nonisolated func isDismissed(ruleID: IndiaComplianceRuleID, financialYear: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let map = userDefaults.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
        return map[Self.storageKey(ruleID: ruleID, financialYear: financialYear)] == true
    }

    nonisolated func dismiss(ruleID: IndiaComplianceRuleID, financialYear: String) {
        lock.lock()
        defer { lock.unlock() }
        var map = userDefaults.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
        map[Self.storageKey(ruleID: ruleID, financialYear: financialYear)] = true
        userDefaults.set(map, forKey: storageKey)
    }

    nonisolated func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: storageKey)
    }

    nonisolated static func storageKey(ruleID: IndiaComplianceRuleID, financialYear: String) -> String {
        "\(ruleID.rawValue)|\(financialYear)"
    }
}
