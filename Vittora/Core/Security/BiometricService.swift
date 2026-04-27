import Foundation
import LocalAuthentication

enum BiometricType: Sendable {
    case faceID, touchID, opticID, none
}

protocol BiometricServiceProtocol: Sendable {
    func canUseBiometrics() -> Bool
    func authenticate(reason: String) async throws -> Bool
    func authenticateWithPasscode(reason: String) async throws -> Bool
    var biometricType: BiometricType { get }
}

@MainActor
final class BiometricService: BiometricServiceProtocol, Sendable {
    private let capabilityContext = LAContext()

    var biometricType: BiometricType {
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

    func canUseBiometrics() -> Bool {
        var error: NSError?
        return capabilityContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async throws -> Bool {
        do {
            return try await evaluate(
                policy: .deviceOwnerAuthenticationWithBiometrics,
                reason: reason,
                fallbackTitle: String(localized: "Use Passcode")
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return false
            case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
                return try await authenticateWithPasscode(reason: reason)
            default:
                throw VittoraError.biometricFailed(error.localizedDescription)
            }
        }
    }

    func authenticateWithPasscode(reason: String) async throws -> Bool {
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
