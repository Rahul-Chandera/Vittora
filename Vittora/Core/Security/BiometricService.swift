import Foundation
import LocalAuthentication

enum BiometricType: Sendable {
    case faceID, touchID, opticID, none
}

protocol BiometricServiceProtocol: Sendable {
    func canUseBiometrics() -> Bool
    func authenticate(reason: String) async throws -> Bool
    var biometricType: BiometricType { get }
}

@MainActor
final class BiometricService: BiometricServiceProtocol, Sendable {
    nonisolated var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
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

    nonisolated func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return false
            case .biometryLockout:
                throw VittoraError.biometricFailed(
                    String(localized: "Biometric authentication is locked out. Please use your device passcode.")
                )
            case .biometryNotAvailable:
                throw VittoraError.biometricFailed(
                    String(localized: "Biometric authentication is not available on this device.")
                )
            case .biometryNotEnrolled:
                throw VittoraError.biometricFailed(
                    String(localized: "No biometric data is enrolled. Please set up Face ID or Touch ID.")
                )
            default:
                throw VittoraError.biometricFailed(error.localizedDescription)
            }
        }
    }
}
