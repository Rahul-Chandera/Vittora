import Foundation

/// Isolated `UserDefaults` suite for non-secret sync metadata (not `standard`, which is backed up broadly).
/// See production review SEC-08.
enum AppUserDefaults {
    /// Suite name for sync timestamps and sync-related preferences.
    static let syncSuiteName = "com.vittora.app.sync"

    /// Suite for on-device conversion milestones (excluded from iCloud backup via suite isolation).
    static let conversionSuiteName = "com.vittora.app.conversion"

    enum StandardKey {
        static let currencyCode = "vittora.currencyCode"
        static let appearanceMode = "vittora.appearanceMode"
        static let notificationsEnabled = "vittora.notificationsEnabled"
        static let notifyBillsDue = "vittora.notifyBillsDue"
        static let notifyBudgetAlerts = "vittora.notifyBudgetAlerts"
        static let notifyGoalMilestones = "vittora.notifyGoalMilestones"
        static let notifyRecurring = "vittora.notifyRecurring"
        static let exportSchedule = "vittora.exportSchedule"
        static let cloudSyncEnabled = "vittora.cloudSyncEnabled"
        static let appLockTimeout = "vittora.appLockTimeout"
        static let appLockEnabledLegacy = "vittora.appLockEnabled"
        static let passcodeFallbackLegacy = "vittora.passcodeFallback"
        static let userNameLegacy = "vittora.userName"
    }

    enum KeychainKey {
        static let appLockEnabled = "vittora.appLockEnabled"
        static let passcodeFallback = "vittora.passcodeFallback"
        static let userName = "vittora.userName"
        static let onboardingComplete = "vittora.onboardingComplete"
    }

    enum SyncKey {
        static let lastSyncDate = "vittora.lastSyncDate"
    }

    /// Returns the sync suite, falling back to standard only if the suite cannot be created.
    static var sync: UserDefaults {
        if let suite = UserDefaults(suiteName: syncSuiteName) {
            return suite
        }
        return .standard
    }

    /// Returns the conversion-event suite, falling back to standard only if the suite cannot be created.
    static var conversion: UserDefaults {
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
