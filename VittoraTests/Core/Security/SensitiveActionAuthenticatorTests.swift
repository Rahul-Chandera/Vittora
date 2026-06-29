import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("SensitiveActionAuthenticator Tests")
@MainActor
struct SensitiveActionAuthenticatorTests {

    @Test("confirm returns true when biometrics succeed")
    func confirmSuccess() async throws {
        let biometric = MockBiometricService()
        biometric.shouldSucceed = true
        let result = try await SensitiveActionAuthenticator.confirm(
            action: .disableAppLock,
            using: biometric
        )
        #expect(result == true)
        #expect(biometric.authenticateCallCount == 1)
        #expect(biometric.lastAllowPasscodeFallback == true)
    }

    @Test("confirm returns false when user cancels")
    func confirmCancelAborts() async throws {
        let biometric = MockBiometricService()
        biometric.shouldSucceed = false
        let result = try await SensitiveActionAuthenticator.confirm(
            action: .factoryReset,
            using: biometric
        )
        #expect(result == false)
    }

    @Test("confirm propagates biometric errors")
    func confirmPropagatesError() async {
        let biometric = MockBiometricService()
        biometric.shouldThrowError = true
        await #expect(throws: VittoraError.self) {
            _ = try await SensitiveActionAuthenticator.confirm(
                action: .disableAppLock,
                using: biometric
            )
        }
    }
}
