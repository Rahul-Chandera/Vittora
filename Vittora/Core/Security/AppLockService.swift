import Foundation

/// User-configurable delay before re-authentication after the app was backgrounded.
enum AppLockTimeout: String, CaseIterable, Sendable {
    case immediately
    case oneMinute
    case fiveMinutes

    var timeInterval: TimeInterval {
        switch self {
        case .immediately: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        }
    }

    var displayName: String {
        switch self {
        case .immediately: return String(localized: "Immediately")
        case .oneMinute: return String(localized: "After 1 minute")
        case .fiveMinutes: return String(localized: "After 5 minutes")
        }
    }
}

/// Pure policy helpers for time-based app lock (testable without biometrics).
enum AppLockPolicy {
    /// Returns true when the app was backgrounded long enough to require re-authentication.
    /// Statutory ordering: compares elapsed time against `timeout` **before** any lock UI is shown on `.active`.
    nonisolated static func shouldLock(backgroundedAt: Date, now: Date, timeout: TimeInterval) -> Bool {
        let elapsed = now.timeIntervalSince(backgroundedAt)
        guard elapsed >= 0 else { return false }
        return elapsed >= timeout
    }
}

protocol AppLockServiceProtocol: Sendable {
    var isLocked: Bool { get }
    var lastBackgroundedAt: Date? { get }
    /// Non-nil while the app is enforcing a post-failure cooldown.
    var cooldownExpiresAt: Date? { get }
    func recordBackgrounded(at date: Date)
    func lock() async
    func unlock() async throws -> Bool
    func unlockWithPasscode() async throws -> Bool
}

@MainActor
final class AppLockService: AppLockServiceProtocol, Sendable {
    private let biometricService: any BiometricServiceProtocol
    private let auditLogger: (any SecurityAuditLogging)?
    private var _isLocked = false
    private(set) var lastBackgroundedAt: Date?

    // MARK: - Rate limiting

    /// Failures before cooldown begins.
    private static let cooldownThreshold = 3
    /// Cooldown durations indexed by (failures - threshold), capped at last value.
    private static let cooldownDurations: [TimeInterval] = [30, 60, 120, 300, 300]

    private var consecutiveFailures = 0
    private(set) var cooldownExpiresAt: Date?

    // MARK: - Protocol properties

    var isLocked: Bool { _isLocked }

    init(
        biometricService: any BiometricServiceProtocol,
        auditLogger: (any SecurityAuditLogging)? = nil
    ) {
        self.biometricService = biometricService
        self.auditLogger = auditLogger
    }

    func recordBackgrounded(at date: Date) {
        lastBackgroundedAt = date
    }

    func lock() async {
        _isLocked = true
        await auditLogger?.record(SecurityAuditEvent(kind: .appLocked, detail: "session"))
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
            await auditLogger?.record(SecurityAuditEvent(
                kind: .appUnlocked,
                detail: usingPasscodeFallback ? "passcode" : "biometric"
            ))
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

    #if DEBUG
    /// Test-only: clears an active cooldown so failure-streak tests can continue without waiting.
    func testing_clearCooldown() {
        cooldownExpiresAt = nil
    }
    #endif
}
