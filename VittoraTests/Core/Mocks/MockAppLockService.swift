import Foundation
@testable import Vittora

@MainActor
final class MockAppLockService: AppLockServiceProtocol, @unchecked Sendable {
    var isLocked: Bool = false
    var lastBackgroundedAt: Date?
    var cooldownExpiresAt: Date? = nil
    var unlockResult: Bool = true
    var shouldThrow: Bool = false

    func recordBackgrounded(at date: Date) {
        lastBackgroundedAt = date
    }

    func lock() async {
        isLocked = true
    }

    func unlock(allowPasscodeFallback: Bool) async throws -> Bool {
        if shouldThrow { throw VittoraError.biometricFailed(String(localized: "Mock biometric error")) }
        if unlockResult { isLocked = false }
        return unlockResult
    }

    func unlockWithPasscode() async throws -> Bool {
        if shouldThrow { throw VittoraError.biometricFailed(String(localized: "Mock passcode error")) }
        if unlockResult { isLocked = false }
        return unlockResult
    }
}
