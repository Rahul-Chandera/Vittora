import Foundation
import Testing
@testable import Vittora

@Suite("BiometricService Tests")
@MainActor
struct BiometricServiceTests {

    // MARK: - Initialization and type detection

    @Test("service initialises without crashing")
    func initSucceeds() {
        let service = BiometricService()
        _ = service.biometricType
    }

    @Test("biometricType returns a valid enum case")
    func biometricTypeIsValid() {
        let service = BiometricService()
        let validTypes: [BiometricType] = [.faceID, .touchID, .opticID, .none]
        #expect(validTypes.contains(service.biometricType))
    }

    @Test("canUseBiometrics returns false on simulator where biometrics are unavailable")
    @available(iOS 18, macOS 15, *)
    func canUseBiometricsOnSimulator() {
        #if targetEnvironment(simulator)
        let service = BiometricService()
        #expect(service.canUseBiometrics() == false)
        #endif
    }

    @Test("biometricType is .none on simulator")
    func biometricTypeNoneOnSimulator() {
        #if targetEnvironment(simulator)
        let service = BiometricService()
        #expect(service.biometricType == .none)
        #endif
    }

    // MARK: - Protocol conformance

    @Test("BiometricService conforms to BiometricServiceProtocol")
    func conformsToProtocol() {
        let service: any BiometricServiceProtocol = BiometricService()
        #expect(service.biometricType == service.biometricType)
    }

    // MARK: - AppLockService integration via mock (covers fallback/lockout paths)

    @Test("authenticate success via mock clears lock state")
    func authenticateSuccessViaAppLock() async throws {
        let mock = MockBiometricService()
        mock.shouldSucceed = true
        let lock = AppLockService(biometricService: mock)

        await lock.lock()
        let result = try await lock.unlock()

        #expect(result == true)
        #expect(lock.isLocked == false)
    }

    @Test("authenticate failure via mock leaves locked state")
    func authenticateFailureViaAppLock() async throws {
        let mock = MockBiometricService()
        mock.shouldSucceed = false
        let lock = AppLockService(biometricService: mock)

        await lock.lock()
        let result = try await lock.unlock()

        #expect(result == false)
        #expect(lock.isLocked == true)
    }

    @Test("biometric error propagates through AppLockService as thrown error")
    func biometricErrorPropagates() async {
        let mock = MockBiometricService()
        mock.shouldThrowError = true
        let lock = AppLockService(biometricService: mock)

        await lock.lock()
        await #expect(throws: VittoraError.self) {
            try await lock.unlock()
        }
    }

    @Test("unlockWithPasscode uses passcode path on mock")
    func unlockWithPasscodeUsesMock() async throws {
        let mock = MockBiometricService()
        mock.shouldSucceed = true
        let lock = AppLockService(biometricService: mock)

        await lock.lock()
        let result = try await lock.unlockWithPasscode()

        #expect(result == true)
        #expect(mock.authenticateCallCount == 1)
    }
}
