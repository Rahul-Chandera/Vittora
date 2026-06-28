import Foundation
@testable import Vittora

/// In-memory cooldown store for tests — simulates Keychain persistence across service re-inits.
final class InMemoryAppLockCooldownStore: AppLockCooldownStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppLockCooldownState?

    func load(now: Date) -> AppLockCooldownState {
        lock.lock()
        defer { lock.unlock() }
        guard let stored else { return AppLockCooldownState() }
        return AppLockCooldownStateLogic.rearmed(from: stored, now: now)
    }

    func save(_ state: AppLockCooldownState) {
        lock.lock()
        defer { lock.unlock() }
        let sanitized = AppLockCooldownStateLogic.rearmed(from: state, now: .now)
        if AppLockCooldownStateLogic.isEmpty(sanitized) {
            stored = nil
        } else {
            stored = sanitized
        }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        stored = nil
    }
}
