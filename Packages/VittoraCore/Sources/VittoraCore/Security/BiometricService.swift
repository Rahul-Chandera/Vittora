import Foundation
import LocalAuthentication

@MainActor
public final class BiometricService: BiometricServiceProtocol, Sendable {
    private let capabilityContext = LAContext()

    public init() {}

    public var biometricType: BiometricType {
        var error: NSError?
        guard capabilityContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch capabilityContext.biometryType {
        case .none:
            return .none
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

    public func canUseBiometrics() -> Bool {
        var error: NSError?
        return capabilityContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func authenticate(reason: String, allowPasscodeFallback: Bool) async throws -> Bool {
        // Pre-flight: when biometrics can't be used at all (not enrolled, not
        // paired, disconnected — e.g. a Mac without a Touch ID keyboard), go
        // straight to device passcode instead of relying on the error-code
        // catch below, which can't enumerate every hardware-absence code.
        guard canUseBiometrics() else {
            guard allowPasscodeFallback else { return false }
            return try await authenticateWithPasscode(reason: reason)
        }
        do {
            return try await evaluate(
                policy: .deviceOwnerAuthenticationWithBiometrics,
                reason: reason,
                fallbackTitle: allowPasscodeFallback ? String(localized: "Use Passcode") : ""
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return false
            case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
                guard allowPasscodeFallback else { return false }
                return try await authenticateWithPasscode(reason: reason)
            default:
                throw VittoraError.biometricFailed(error.localizedDescription)
            }
        }
    }

    public func authenticateWithPasscode(reason: String) async throws -> Bool {
        do {
            return try await evaluate(policy: .deviceOwnerAuthentication, reason: reason)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return false
            default:
                throw VittoraError.biometricFailed(error.localizedDescription)
            }
        }
    }

    private func evaluate(
        policy: LAPolicy,
        reason: String,
        fallbackTitle: String? = nil
    ) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        if let fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        }

        return try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}
