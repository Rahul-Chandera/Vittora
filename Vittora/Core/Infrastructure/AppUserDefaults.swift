import Foundation

/// Isolated `UserDefaults` suite for non-secret sync metadata (not `standard`, which is backed up broadly).
/// See production review SEC-08.
enum AppUserDefaults {
    /// Suite name for sync timestamps and sync-related preferences.
    nonisolated static let syncSuiteName = "com.vittora.app.sync"

    /// Suite for on-device conversion milestones (excluded from iCloud backup via suite isolation).
    nonisolated static let conversionSuiteName = "com.vittora.app.conversion"

    enum StandardKey {
        nonisolated static let currencyCode = "vittora.currencyCode"
        nonisolated static let appearanceMode = "vittora.appearanceMode"
        nonisolated static let notificationsEnabled = "vittora.notificationsEnabled"
        nonisolated static let notifyBillsDue = "vittora.notifyBillsDue"
        nonisolated static let notifyBudgetAlerts = "vittora.notifyBudgetAlerts"
        nonisolated static let notifyGoalMilestones = "vittora.notifyGoalMilestones"
        nonisolated static let notifyRecurring = "vittora.notifyRecurring"
        nonisolated static let exportSchedule = "vittora.exportSchedule"
        nonisolated static let cloudSyncEnabled = "vittora.cloudSyncEnabled"
        nonisolated static let appLockTimeout = "vittora.appLockTimeout"
        /// Legacy UserDefaults location for app-lock intent before keychain migration (B1).
        /// Intentionally matches `KeychainKey.appLockEnabled` so reads can migrate UD → keychain.
        nonisolated static let appLockEnabledLegacy = "vittora.appLockEnabled"
        /// Legacy UserDefaults location; matches `KeychainKey.passcodeFallback`.
        nonisolated static let passcodeFallbackLegacy = "vittora.passcodeFallback"
        /// Legacy UserDefaults location; matches `KeychainKey.userName`.
        nonisolated static let userNameLegacy = "vittora.userName"
        nonisolated static let budgetThresholdFired = "vittora.budgetThresholdFired"
    }

    enum KeychainKey {
        /// Keychain location for app-lock intent (migrated from `StandardKey.appLockEnabledLegacy`).
        nonisolated static let appLockEnabled = "vittora.appLockEnabled"
        nonisolated static let passcodeFallback = "vittora.passcodeFallback"
        nonisolated static let userName = "vittora.userName"
        nonisolated static let onboardingComplete = "vittora.onboardingComplete"
        nonisolated static let appLockCooldown = "vittora.appLockCooldown"
    }

    enum SyncKey {
        nonisolated static let lastSyncDate = "vittora.lastSyncDate"
    }

    /// Returns the sync suite, falling back to standard only if the suite cannot be created.
    nonisolated static var sync: UserDefaults {
        if let suite = UserDefaults(suiteName: syncSuiteName) {
            return suite
        }
        return .standard
    }

    /// Returns the conversion-event suite, falling back to standard only if the suite cannot be created.
    nonisolated static var conversion: UserDefaults {
        if let suite = UserDefaults(suiteName: conversionSuiteName) {
            return suite
        }
        return .standard
    }

    /// One-time migration of `vittora.lastSyncDate` from `.standard` into the sync suite.
    static func migrateLastSyncDateIfNeeded() {
        let standard = UserDefaults.standard
        let key = SyncKey.lastSyncDate
        guard standard.object(forKey: key) != nil else { return }
        if sync.object(forKey: key) == nil,
           let date = standard.object(forKey: key) as? Date {
            sync.set(date, forKey: key)
        }
        standard.removeObject(forKey: key)
    }
}
