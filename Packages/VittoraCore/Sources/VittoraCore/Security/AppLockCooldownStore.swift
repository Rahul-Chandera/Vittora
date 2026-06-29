import Foundation

public struct AppLockCooldownState: Equatable, Sendable {
    public var consecutiveFailures: Int
    public var cooldownExpiresAt: Date?

    public nonisolated init(consecutiveFailures: Int = 0, cooldownExpiresAt: Date? = nil) {
        self.consecutiveFailures = consecutiveFailures
        self.cooldownExpiresAt = cooldownExpiresAt
    }
}

extension AppLockCooldownState: Codable {
    enum CodingKeys: String, CodingKey {
        case consecutiveFailures
        case cooldownExpiresAt
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consecutiveFailures = try container.decode(Int.self, forKey: .consecutiveFailures)
        cooldownExpiresAt = try container.decodeIfPresent(Date.self, forKey: .cooldownExpiresAt)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consecutiveFailures, forKey: .consecutiveFailures)
        try container.encodeIfPresent(cooldownExpiresAt, forKey: .cooldownExpiresAt)
    }
}

public enum AppLockCooldownStateLogic {
    /// Clears an expired cooldown while preserving the failure streak for escalation.
    public nonisolated static func rearmed(from state: AppLockCooldownState, now: Date) -> AppLockCooldownState {
        var result = state
        if let expires = result.cooldownExpiresAt, expires <= now {
            result.cooldownExpiresAt = nil
        }
        return result
    }

    public nonisolated static func isEmpty(_ state: AppLockCooldownState) -> Bool {
        state.consecutiveFailures == 0 && state.cooldownExpiresAt == nil
    }
}

public final class KeychainAppLockCooldownStore: AppLockCooldownStoring, Sendable {
    public static let keychainKey = AppUserDefaults.KeychainKey.appLockCooldown

    private let key: String

    public init(key: String = keychainKey) {
        self.key = key
    }

    public nonisolated func load(now: Date) -> AppLockCooldownState {
        guard let data = KeychainService.syncLoad(forKey: key),
              let decoded = try? JSONDecoder().decode(AppLockCooldownState.self, from: data)
        else {
            return AppLockCooldownState()
        }
        return AppLockCooldownStateLogic.rearmed(from: decoded, now: now)
    }

    public nonisolated func save(_ state: AppLockCooldownState) {
        let sanitized = AppLockCooldownStateLogic.rearmed(from: state, now: .now)
        if AppLockCooldownStateLogic.isEmpty(sanitized) {
            KeychainService.syncDelete(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(sanitized) else { return }
        KeychainService.syncSave(data, forKey: key)
    }

    public nonisolated func clear() {
        KeychainService.syncDelete(forKey: key)
    }
}
