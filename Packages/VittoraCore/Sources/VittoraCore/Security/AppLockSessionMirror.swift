import Foundation

/// Persists App Lock *policy inputs* in the App Group so extension/intent
/// processes can evaluate `AppLockDisclosureGate` with the same rule as
/// `applyAppLockPolicyOnBecomeActive` — without the in-memory `AppState`.
///
/// Fail-closed while App Lock is enabled: missing/unreadable timeout,
/// missing/unreadable session-authenticated flag, or an unreadable
/// backgrounded timestamp → treat as locked.
public enum AppLockSessionMirror: Sendable {
    public nonisolated static let backgroundedAtKey = "vittora.appLockBackgroundedAt"
    public nonisolated static let timeoutIntervalKey = "vittora.appLockTimeoutInterval"
    public nonisolated static let sessionAuthenticatedKey = "vittora.appLockSessionAuthenticated"
    /// Legacy boolean snapshot (W5); cleared on write so stale `true` cannot bypass the gate.
    public nonisolated static let isSessionUnlockedKey = "vittora.appLockSessionUnlocked"

    /// Keychain (authoritative) with legacy UserDefaults fallback — mirrors Settings.
    public nonisolated static var isAppLockEnabled: Bool {
        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.appLockEnabled) {
            return data.first == 1
        }
        return UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.appLockEnabledLegacy)
    }

    /// Whether disclosure should be withheld right now (uses `.now`).
    public nonisolated static var isAppLocked: Bool {
        evaluateIsAppLocked(isAppLockEnabled: isAppLockEnabled, now: .now)
    }

    /// Reads mirrored policy inputs and applies the become-active lock rule.
    /// `now` is injectable for tests; `isAppLockEnabled` is injectable so tests
    /// can exercise the App Group path without touching the Keychain.
    public nonisolated static func evaluateIsAppLocked(
        isAppLockEnabled: Bool,
        now: Date = .now
    ) -> Bool {
        guard isAppLockEnabled else { return false }

        let defaults = AppUserDefaults.appGroup

        guard defaults.object(forKey: timeoutIntervalKey) != nil else { return true }
        let timeout = defaults.double(forKey: timeoutIntervalKey)
        guard timeout >= 0, timeout.isFinite else { return true }

        if defaults.object(forKey: backgroundedAtKey) != nil {
            guard let backgroundedAt = defaults.object(forKey: backgroundedAtKey) as? Date else {
                return true
            }
            if AppLockPolicy.shouldLock(backgroundedAt: backgroundedAt, now: now, timeout: timeout) {
                return true
            }
        }

        guard defaults.object(forKey: sessionAuthenticatedKey) != nil else { return true }
        return !defaults.bool(forKey: sessionAuthenticatedKey)
    }

    /// Call when the host records a background transition (`recordBackgrounded`).
    public nonisolated static func mirrorBackgrounded(at date: Date, timeout: TimeInterval) {
        let defaults = AppUserDefaults.appGroup
        defaults.set(date, forKey: backgroundedAtKey)
        defaults.set(timeout, forKey: timeoutIntervalKey)
        defaults.removeObject(forKey: isSessionUnlockedKey)
    }

    /// Resets all mirrored policy inputs (factory reset / tests). Fail-closed afterward.
    public nonisolated static func clearAll() {
        let defaults = AppUserDefaults.appGroup
        defaults.removeObject(forKey: backgroundedAtKey)
        defaults.removeObject(forKey: timeoutIntervalKey)
        defaults.removeObject(forKey: sessionAuthenticatedKey)
        defaults.removeObject(forKey: isSessionUnlockedKey)
    }

    /// Mirrors foreground session + timeout. Clears a stale background stamp when unlocked
    /// so Siri does not keep treating a pre-unlock background as still locking.
    public nonisolated static func mirrorFromAppState(
        isAppLockEnabled: Bool,
        isLocked: Bool,
        isAuthenticated: Bool,
        timeout: TimeInterval
    ) {
        let defaults = AppUserDefaults.appGroup
        let authenticated = !isAppLockEnabled || (!isLocked && isAuthenticated)
        defaults.set(authenticated, forKey: sessionAuthenticatedKey)
        defaults.set(timeout, forKey: timeoutIntervalKey)
        defaults.removeObject(forKey: isSessionUnlockedKey)
        if authenticated {
            defaults.removeObject(forKey: backgroundedAtKey)
        }
    }
}
