import Foundation
import Testing
@testable import Vittora

@Suite("AppLockService Tests")
@MainActor
struct AppLockServiceTests {

    private func makeService(
        shouldSucceed: Bool = true,
        shouldThrow: Bool = false
    ) -> (AppLockService, MockBiometricService) {
        let biometric = MockBiometricService()
        biometric.shouldSucceed = shouldSucceed
        biometric.shouldThrowError = shouldThrow
        let service = AppLockService(biometricService: biometric)
        return (service, biometric)
    }

    // MARK: - Initial state

    @Test("service starts unlocked")
    func startsUnlocked() async {
        let (service, _) = makeService()
        #expect(service.isLocked == false)
    }

    @Test("cooldownExpiresAt is nil on init")
    func cooldownNilOnInit() async {
        let (service, _) = makeService()
        #expect(service.cooldownExpiresAt == nil)
    }

    // MARK: - Lock

    @Test("lock() sets isLocked to true")
    func lockSetsIsLocked() async {
        let (service, _) = makeService()
        await service.lock()
        #expect(service.isLocked == true)
    }

    @Test("lock() can be called multiple times without error")
    func lockIdempotent() async {
        let (service, _) = makeService()
        await service.lock()
        await service.lock()
        #expect(service.isLocked == true)
    }

    // MARK: - Unlock (biometric)

    @Test("unlock() returns true and clears lock on success")
    func unlockSuccessClears() async throws {
        let (service, _) = makeService(shouldSucceed: true)
        await service.lock()
        let result = try await service.unlock()
        #expect(result == true)
        #expect(service.isLocked == false)
    }

    @Test("unlock() returns false and stays locked on biometric failure")
    func unlockFailureStaysLocked() async throws {
        let (service, biometric) = makeService(shouldSucceed: false)
        biometric.shouldSucceed = false
        await service.lock()
        let result = try await service.unlock()
        #expect(result == false)
        #expect(service.isLocked == true)
    }

    @Test("unlock() propagates thrown biometric errors")
    func unlockPropagatesError() async {
        let (service, _) = makeService(shouldThrow: true)
        await service.lock()
        await #expect(throws: VittoraError.self) {
            _ = try await service.unlock()
        }
    }

    // MARK: - Unlock with passcode

    @Test("unlockWithPasscode() returns true and clears lock on success")
    func passcodeUnlockSuccess() async throws {
        let (service, _) = makeService(shouldSucceed: true)
        await service.lock()
        let result = try await service.unlockWithPasscode()
        #expect(result == true)
        #expect(service.isLocked == false)
    }

    @Test("unlockWithPasscode() returns false and stays locked on failure")
    func passcodeUnlockFailure() async throws {
        let (service, biometric) = makeService()
        biometric.shouldSucceed = false
        await service.lock()
        let result = try await service.unlockWithPasscode()
        #expect(result == false)
        #expect(service.isLocked == true)
    }

    // MARK: - Failure counting and cooldown

    @Test("three failures do not yet trigger cooldown")
    func threeFailuresNoCooldown() async throws {
        let (service, biometric) = makeService()
        biometric.shouldSucceed = false
        for _ in 1...3 {
            _ = try await service.unlock()
        }
        #expect(service.cooldownExpiresAt == nil)
    }

    @Test("fourth failure triggers cooldown")
    func fourthFailureTriggersCooldown() async throws {
        let (service, biometric) = makeService()
        biometric.shouldSucceed = false
        for _ in 1...4 {
            _ = try await service.unlock()
        }
        #expect(service.cooldownExpiresAt != nil)
        #expect(service.cooldownExpiresAt! > .now)
    }

    @Test("fifth failure escalates cooldown duration")
    func fifthFailureEscalatesDuration() async throws {
        let (service, biometric) = makeService()
        biometric.shouldSucceed = false

        var cooldownAfterFourth: Date?
        for i in 1...4 {
            _ = try await service.unlock()
            if i == 4 { cooldownAfterFourth = service.cooldownExpiresAt }
        }
        service.testing_clearCooldown()
        _ = try await service.unlock()

        let cooldownAfterFifth = service.cooldownExpiresAt
        #expect(cooldownAfterFourth != nil)
        #expect(cooldownAfterFifth != nil)
        #expect(cooldownAfterFifth! > cooldownAfterFourth!)
    }

    @Test("unlock during active cooldown throws without calling biometrics")
    func unlockDuringCooldownThrows() async throws {
        let (service, biometric) = makeService()
        biometric.shouldSucceed = false

        // Trigger cooldown (need 4 failures)
        for _ in 1...4 {
            _ = try await service.unlock()
        }
        #expect(service.cooldownExpiresAt != nil)

        // The next attempt should throw, not call biometrics
        let callsBeforeCooldownAttempt = biometric.authenticateCallCount
        await #expect(throws: VittoraError.self) {
            _ = try await service.unlock()
        }
        #expect(biometric.authenticateCallCount == callsBeforeCooldownAttempt)
    }

    @Test("successful unlock resets failure count and clears cooldown")
    func successResetsFailureCount() async throws {
        let (service, biometric) = makeService()

        // Accumulate 2 failures (below cooldown threshold)
        biometric.shouldSucceed = false
        _ = try await service.unlock()
        _ = try await service.unlock()

        // Succeed — should clear state
        biometric.shouldSucceed = true
        let result = try await service.unlock()

        #expect(result == true)
        #expect(service.cooldownExpiresAt == nil)
        #expect(service.isLocked == false)

        // A new failure streak should restart from zero (3 failures → no cooldown again)
        biometric.shouldSucceed = false
        for _ in 1...3 {
            _ = try await service.unlock()
        }
        #expect(service.cooldownExpiresAt == nil)
    }

    // MARK: - Background timestamp

    @Test("recordBackgrounded stores the timestamp")
    func recordBackgroundedStoresTimestamp() {
        let (service, _) = makeService()
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        service.recordBackgrounded(at: stamp)
        #expect(service.lastBackgroundedAt == stamp)
    }

    // MARK: - AppLockPolicy.shouldLock

    @Test("shouldLock is false when elapsed time is below timeout")
    func shouldLockFalseBelowTimeout() {
        let backgrounded = Date(timeIntervalSince1970: 0)
        let now = backgrounded.addingTimeInterval(299)
        #expect(AppLockPolicy.shouldLock(backgroundedAt: backgrounded, now: now, timeout: 300) == false)
    }

    @Test("shouldLock is true at exactly the timeout boundary")
    func shouldLockTrueAtBoundary() {
        let backgrounded = Date(timeIntervalSince1970: 0)
        let now = backgrounded.addingTimeInterval(300)
        #expect(AppLockPolicy.shouldLock(backgroundedAt: backgrounded, now: now, timeout: 300) == true)
    }

    @Test("shouldLock is true immediately when timeout is zero")
    func shouldLockImmediateTimeout() {
        let backgrounded = Date(timeIntervalSince1970: 0)
        let now = backgrounded
        #expect(AppLockPolicy.shouldLock(backgroundedAt: backgrounded, now: now, timeout: 0) == true)
    }

    @Test("shouldLock is false when now precedes backgroundedAt")
    func shouldLockFalseWhenClockSkew() {
        let backgrounded = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 50)
        #expect(AppLockPolicy.shouldLock(backgroundedAt: backgrounded, now: now, timeout: 0) == false)
    }
}
