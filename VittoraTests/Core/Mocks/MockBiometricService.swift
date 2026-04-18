import Foundation
@testable import Vittora

@MainActor
final class MockBiometricService: BiometricServiceProtocol, Sendable {
    private(set) var authenticateCallCount = 0
    var shouldSucceed = true
    var shouldThrowError = false
    var throwError: VittoraError = .biometricFailed(String(localized: "Mock error"))
    var mockBiometricType: BiometricType = .faceID

    var biometricType: BiometricType { mockBiometricType }

    func canUseBiometrics() -> Bool {
        true
    }

    func authenticate(reason: String) async throws -> Bool {
        authenticateCallCount += 1

        if shouldThrowError {
            throw throwError
        }

        return shouldSucceed
    }

    func authenticateWithPasscode(reason: String) async throws -> Bool {
        authenticateCallCount += 1

        if shouldThrowError {
            throw throwError
        }

        return shouldSucceed
    }

    func reset() {
        authenticateCallCount = 0
        shouldSucceed = true
        shouldThrowError = false
    }
}
