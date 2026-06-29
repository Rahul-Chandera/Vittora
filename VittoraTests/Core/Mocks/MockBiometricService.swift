import Foundation
import VittoraCore

@MainActor
final class MockBiometricService: BiometricServiceProtocol, Sendable {
    private(set) var authenticateCallCount = 0
    private(set) var lastAllowPasscodeFallback: Bool?
    private(set) var passcodeAuthenticateCallCount = 0
    var shouldSucceed = true
    var shouldThrowError = false
    var simulateBiometryUnavailable = false
    var throwError: VittoraError = .biometricFailed(String(localized: "Mock error"))
    var mockBiometricType: BiometricType = .faceID

    var biometricType: BiometricType { mockBiometricType }

    func canUseBiometrics() -> Bool {
        true
    }

    func authenticate(reason: String, allowPasscodeFallback: Bool) async throws -> Bool {
        authenticateCallCount += 1
        lastAllowPasscodeFallback = allowPasscodeFallback

        if shouldThrowError {
            throw throwError
        }

        if simulateBiometryUnavailable {
            guard allowPasscodeFallback else { return false }
            return try await authenticateWithPasscode(reason: reason)
        }

        return shouldSucceed
    }

    func authenticateWithPasscode(reason: String) async throws -> Bool {
        passcodeAuthenticateCallCount += 1
        authenticateCallCount += 1

        if shouldThrowError {
            throw throwError
        }

        return shouldSucceed
    }

    func reset() {
        authenticateCallCount = 0
        passcodeAuthenticateCallCount = 0
        lastAllowPasscodeFallback = nil
        shouldSucceed = true
        shouldThrowError = false
        simulateBiometryUnavailable = false
    }
}
