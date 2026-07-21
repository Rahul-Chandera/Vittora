import Foundation

/// Isolated `UserDefaults` suite for non-secret sync metadata (not `standard`, which is backed up broadly).
/// See production review SEC-08.
public enum AppUserDefaults {
    /// Suite name for sync timestamps and sync-related preferences.
    public nonisolated static let syncSuiteName = "com.vittora.app.sync"

    /// Suite for on-device conversion milestones (excluded from iCloud backup via suite isolation).
    public nonisolated static let conversionSuiteName = "com.vittora.app.conversion"

    public enum StandardKey {
        public nonisolated static let currencyCode = "vittora.currencyCode"
        public nonisolated static let appearanceMode = "vittora.appearanceMode"
        public nonisolated static let notificationsEnabled = "vittora.notificationsEnabled"
        public nonisolated static let notifyBillsDue = "vittora.notifyBillsDue"
        public nonisolated static let notifyBudgetAlerts = "vittora.notifyBudgetAlerts"
        public nonisolated static let notifyGoalMilestones = "vittora.notifyGoalMilestones"
        public nonisolated static let notifyRecurring = "vittora.notifyRecurring"
        public nonisolated static let notificationDeliveryTime = "vittora.notificationDeliveryTime"
        public nonisolated static let notificationQuietHoursEnabled = "vittora.notificationQuietHoursEnabled"
        public nonisolated static let notificationQuietHoursStart = "vittora.notificationQuietHoursStart"
        public nonisolated static let notificationQuietHoursEnd = "vittora.notificationQuietHoursEnd"
        public nonisolated static let billReminderLeadDays = "vittora.billReminderLeadDays"
        public nonisolated static let exportSchedule = "vittora.exportSchedule"
        public nonisolated static let cloudSyncEnabled = "vittora.cloudSyncEnabled"
        public nonisolated static let appLockTimeout = "vittora.appLockTimeout"
        /// Legacy UserDefaults location for app-lock intent before keychain migration (B1).
        /// Intentionally matches `KeychainKey.appLockEnabled` so reads can migrate UD → keychain.
        public nonisolated static let appLockEnabledLegacy = "vittora.appLockEnabled"
        /// Legacy UserDefaults location; matches `KeychainKey.passcodeFallback`.
        public nonisolated static let passcodeFallbackLegacy = "vittora.passcodeFallback"
        /// Legacy UserDefaults location; matches `KeychainKey.userName`.
        public nonisolated static let userNameLegacy = "vittora.userName"
        public nonisolated static let budgetThresholdFired = "vittora.budgetThresholdFired"
        public nonisolated static let categorizationRules = "vittora.categorizationRules"
        public nonisolated static let transactionEditHistory = "vittora.transactionEditHistory"
        public nonisolated static let savedTransactionFilters = "vittora.savedTransactionFilters"
        public nonisolated static let emergencyFundAccountIDs = "vittora.emergencyFundAccountIDs"
        /// When false, transactions are removed from Spotlight (default ON / unset).
        public nonisolated static let spotlightIndexingEnabled = "vittora.spotlightIndexingEnabled"
    }

    public enum KeychainKey {
        /// Keychain location for app-lock intent (migrated from `StandardKey.appLockEnabledLegacy`).
        public nonisolated static let appLockEnabled = "vittora.appLockEnabled"
        public nonisolated static let passcodeFallback = "vittora.passcodeFallback"
        public nonisolated static let userName = "vittora.userName"
        public nonisolated static let onboardingComplete = "vittora.onboardingComplete"
        public nonisolated static let appLockCooldown = "vittora.appLockCooldown"
    }

    public enum SyncKey {
        public nonisolated static let lastSyncDate = "vittora.lastSyncDate"
    }

    /// Returns the sync suite, falling back to standard only if the suite cannot be created.
    public nonisolated static var sync: UserDefaults {
        if let suite = UserDefaults(suiteName: syncSuiteName) {
            return suite
        }
        return .standard
    }

    /// Returns the conversion-event suite, falling back to standard only if the suite cannot be created.
    public nonisolated static var conversion: UserDefaults {
        if let suite = UserDefaults(suiteName: conversionSuiteName) {
            return suite
        }
        return .standard
    }

    /// App Group suite shared with extensions (widgets). Falls back to `.standard` if unavailable.
    public nonisolated static var appGroup: UserDefaults {
        if let suite = UserDefaults(suiteName: AppGroupConfiguration.identifier) {
            return suite
        }
        return .standard
    }

    /// Mirrors the app currency into the App Group suite without moving `.standard` storage.
    /// Extensions cannot see the host app's `.standard` defaults.
    public nonisolated static func mirrorCurrencyCodeToAppGroup() {
        let key = StandardKey.currencyCode
        if let code = UserDefaults.standard.string(forKey: key) {
            appGroup.set(code, forKey: key)
        }
    }

    /// One-time migration of `vittora.lastSyncDate` from `.standard` into the sync suite.
    public static func migrateLastSyncDateIfNeeded() {
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
