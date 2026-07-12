import Foundation
import LocalAuthentication
import VittoraCore

@MainActor
final class MockBiometricService: BiometricServiceProtocol, Sendable {
    private(set) var authenticateCallCount = 0
    private(set) var lastAllowPasscodeFallback: Bool?
    private(set) var passcodeAuthenticateCallCount = 0
    var shouldSucceed = true
    var shouldThrowError = false
    var simulateBiometryUnavailable = false
    /// When set, `authenticate` mirrors real `BiometricService` LAError handling.
    var simulatedLAErrorCode: LAError.Code?
    /// When set, `authenticateWithPasscode` applies LAError cancel/throw semantics.
    var simulatedPasscodeLAErrorCode: LAError.Code?
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

        if let code = simulatedLAErrorCode {
            return try await handleLAError(code, reason: reason, allowPasscodeFallback: allowPasscodeFallback)
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

        if let code = simulatedPasscodeLAErrorCode {
            return try handlePasscodeLAError(code)
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
        simulatedLAErrorCode = nil
        simulatedPasscodeLAErrorCode = nil
    }

    private func handleLAError(
        _ code: LAError.Code,
        reason: String,
        allowPasscodeFallback: Bool
    ) async throws -> Bool {
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return false
        case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
            guard allowPasscodeFallback else { return false }
            return try await authenticateWithPasscode(reason: reason)
        default:
            throw VittoraError.biometricFailed(LAError(code).localizedDescription)
        }
    }

    private func handlePasscodeLAError(_ code: LAError.Code) throws -> Bool {
        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return false
        default:
            throw VittoraError.biometricFailed(LAError(code).localizedDescription)
        }
    }
}
