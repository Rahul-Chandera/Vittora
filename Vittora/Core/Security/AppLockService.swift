import Foundation

protocol AppLockServiceProtocol: Sendable {
    var isLocked: Bool { get }
    var lockTimeout: TimeInterval { get set }
    func lock() async
    func unlock() async throws -> Bool
}

@MainActor
final class AppLockService: AppLockServiceProtocol, Sendable {
    private let biometricService: any BiometricServiceProtocol
    private var _isLocked = false
    private var lastActivityTime = Date()
    private var _lockTimeout: TimeInterval = 300
    private var lockTask: Task<Void, Never>?

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
        let reason = String(localized: "Unlock Vittora to continue")
        let success = try await biometricService.authenticate(reason: reason)

        if success {
            _isLocked = false
            lastActivityTime = Date()
            resetLockTimer()
        }

        return success
    }

    func recordActivity() {
        lastActivityTime = Date()
        resetLockTimer()
    }

    private func resetLockTimer() {
        lockTask?.cancel()
        let timeout = _lockTimeout
        lockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            await self?.lock()
        }
    }
}
