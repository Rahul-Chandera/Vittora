import Foundation

/// Persists App Lock session unlock state in the App Group so extension/intent
/// processes can enforce `AppLockDisclosureGate` without the in-memory `AppState`.
///
/// Fail-closed: missing unlock flag is treated as locked when App Lock is enabled.
public enum AppLockSessionMirror: Sendable {
    public nonisolated static let isSessionUnlockedKey = "vittora.appLockSessionUnlocked"

    /// Keychain (authoritative) with legacy UserDefaults fallback — mirrors Settings.
    public nonisolated static var isAppLockEnabled: Bool {
        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.appLockEnabled) {
            return data.first == 1
        }
        return UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.appLockEnabledLegacy)
    }

    /// `true` when the host app last mirrored an unlocked, authenticated session.
    public nonisolated static var isSessionUnlocked: Bool {
        AppUserDefaults.appGroup.bool(forKey: isSessionUnlockedKey)
    }

    /// Effectively locked for disclosure: enabled App Lock without an unlocked session.
    public nonisolated static var isAppLocked: Bool {
        !isSessionUnlocked
    }

    /// Call from the host app whenever lock UI would show or hide.
    public nonisolated static func mirrorSessionUnlocked(_ unlocked: Bool) {
        AppUserDefaults.appGroup.set(unlocked, forKey: isSessionUnlockedKey)
    }

    /// Convenience: unlocked only when App Lock is off, or the session is authenticated and not locked.
    public nonisolated static func mirrorFromAppState(
        isAppLockEnabled: Bool,
        isLocked: Bool,
        isAuthenticated: Bool
    ) {
        let unlocked = !isAppLockEnabled || (!isLocked && isAuthenticated)
        mirrorSessionUnlocked(unlocked)
    }
}
