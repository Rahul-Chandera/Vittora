import Foundation

struct AppLockCooldownState: Codable, Equatable, Sendable {
    var consecutiveFailures: Int
    var cooldownExpiresAt: Date?

    init(consecutiveFailures: Int = 0, cooldownExpiresAt: Date? = nil) {
        self.consecutiveFailures = consecutiveFailures
        self.cooldownExpiresAt = cooldownExpiresAt
    }
}

enum AppLockCooldownStateLogic {
    /// Clears an expired cooldown while preserving the failure streak for escalation.
    nonisolated static func rearmed(from state: AppLockCooldownState, now: Date) -> AppLockCooldownState {
        var result = state
        if let expires = result.cooldownExpiresAt, expires <= now {
            result.cooldownExpiresAt = nil
        }
        return result
    }

    nonisolated static func isEmpty(_ state: AppLockCooldownState) -> Bool {
        state.consecutiveFailures == 0 && state.cooldownExpiresAt == nil
    }
}

protocol AppLockCooldownStoring: Sendable {
    func load(now: Date) -> AppLockCooldownState
    func save(_ state: AppLockCooldownState)
    func clear()
}

extension AppLockCooldownStoring {
    func load() -> AppLockCooldownState {
        load(now: .now)
    }
}

final class KeychainAppLockCooldownStore: AppLockCooldownStoring, Sendable {
    static let keychainKey = AppUserDefaults.KeychainKey.appLockCooldown

    private let key: String

    init(key: String = keychainKey) {
        self.key = key
    }

    nonisolated func load(now: Date) -> AppLockCooldownState {
        guard let data = KeychainService.syncLoad(forKey: key),
              let decoded = try? JSONDecoder().decode(AppLockCooldownState.self, from: data)
        else {
            return AppLockCooldownState()
        }
        return AppLockCooldownStateLogic.rearmed(from: decoded, now: now)
    }

    nonisolated func save(_ state: AppLockCooldownState) {
        let sanitized = AppLockCooldownStateLogic.rearmed(from: state, now: .now)
        if AppLockCooldownStateLogic.isEmpty(sanitized) {
            KeychainService.syncDelete(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(sanitized) else { return }
        KeychainService.syncSave(data, forKey: key)
    }

    nonisolated func clear() {
        KeychainService.syncDelete(forKey: key)
    }
}
