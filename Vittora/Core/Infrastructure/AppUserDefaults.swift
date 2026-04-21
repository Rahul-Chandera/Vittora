import Foundation

/// Isolated `UserDefaults` suite for non-secret sync metadata (not `standard`, which is backed up broadly).
/// See production review SEC-08.
enum AppUserDefaults {
    /// Suite name for sync timestamps and sync-related preferences.
    static let syncSuiteName = "com.vittora.app.sync"

    /// Returns the sync suite, falling back to standard only if the suite cannot be created.
    static var sync: UserDefaults {
        if let suite = UserDefaults(suiteName: syncSuiteName) {
            return suite
        }
        return .standard
    }

    /// One-time migration of `vittora.lastSyncDate` from `.standard` into the sync suite.
    static func migrateLastSyncDateIfNeeded() {
        let standard = UserDefaults.standard
        let key = "vittora.lastSyncDate"
        guard standard.object(forKey: key) != nil else { return }
        if sync.object(forKey: key) == nil,
           let date = standard.object(forKey: key) as? Date {
            sync.set(date, forKey: key)
        }
        standard.removeObject(forKey: key)
    }
}
