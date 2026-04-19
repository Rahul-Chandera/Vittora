import Foundation
import os

protocol AppLockServiceProtocol: Sendable {
    var isLocked: Bool { get }
    var lockTimeout: TimeInterval { get set }
    /// Non-nil while the app is enforcing a post-failure cooldown.
    var cooldownExpiresAt: Date? { get }
    func lock() async
    func unlock() async throws -> Bool
    func unlockWithPasscode() async throws -> Bool
}

@MainActor
final class AppLockService: AppLockServiceProtocol, Sendable {
    private let biometricService: any BiometricServiceProtocol
    private var _isLocked = false
    private var lastActivityTime = Date()
    private var _lockTimeout: TimeInterval = 300
    private var lockTask: Task<Void, Never>?

    // MARK: - Rate limiting

    /// Failures before cooldown begins.
    private static let cooldownThreshold = 3
    /// Cooldown durations indexed by (failures - threshold), capped at last value.
    private static let cooldownDurations: [TimeInterval] = [30, 60, 120, 300, 300]

    private var consecutiveFailures = 0
    private(set) var cooldownExpiresAt: Date?

    // MARK: - Protocol properties

    var isLocked: Bool { _isLocked }
    var lockTimeout: TimeInterval {
        get { _lockTimeout }
        set {
            _lockTimeout = newValue
            resetLockTimer()
        }
    }

    init(biometricService: any BiometricServiceProtocol) {
        self.biometricService = biometricService
        resetLockTimer()
    }

    func lock() async {
        _isLocked = true
        lockTask?.cancel()
    }

    func unlock() async throws -> Bool {
        try await performUnlock(usingPasscodeFallback: false)
    }

    func unlockWithPasscode() async throws -> Bool {
        try await performUnlock(usingPasscodeFallback: true)
    }

    // MARK: - Private helpers

    private func performUnlock(usingPasscodeFallback: Bool) async throws -> Bool {
        try guardCooldown()

        let reason = String(localized: "Unlock Vittora to continue")
        let success: Bool
        if usingPasscodeFallback {
            success = try await biometricService.authenticateWithPasscode(reason: reason)
        } else {
            success = try await biometricService.authenticate(reason: reason)
        }

        if success {
            consecutiveFailures = 0
            cooldownExpiresAt = nil
            _isLocked = false
            lastActivityTime = Date()
            resetLockTimer()
        } else {
            recordFailure()
        }
        return success
    }

    /// Throws if currently in a rate-limit cooldown period.
    private func guardCooldown() throws {
        guard let expires = cooldownExpiresAt, expires > .now else { return }
        let remaining = Int(expires.timeIntervalSince(.now).rounded(.up))
        PerformanceLogger.Security.cooldownBlocked(remainingSeconds: remaining)
        throw VittoraError.biometricFailed(
            String(localized: "Too many failed attempts. Try again in \(remaining) seconds.")
        )
    }

    private func recordFailure() {
        consecutiveFailures += 1
        PerformanceLogger.Security.authFailed(consecutiveCount: consecutiveFailures)
        let excess = consecutiveFailures - Self.cooldownThreshold
        guard excess > 0 else { return }
        let index = min(excess - 1, Self.cooldownDurations.count - 1)
        let duration = Self.cooldownDurations[index]
        cooldownExpiresAt = Date.now.addingTimeInterval(duration)
        PerformanceLogger.Security.cooldownStarted(seconds: Int(duration))
    }

    func recordActivity() {
        lastActivityTime = Date()
        resetLockTimer()
    }

    private func resetLockTimer() {
        lockTask?.cancel()
        let timeout = _lockTimeout
        lockTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(timeout))
            } catch {
                return
            }
            await self?.lock()
        }
    }
}
