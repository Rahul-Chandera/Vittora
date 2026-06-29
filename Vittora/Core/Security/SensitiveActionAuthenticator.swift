import Foundation
import VittoraCore

/// Destructive or security-downgrade actions that require device authentication (B3).
enum SensitiveAction: Sendable {
    case disableAppLock
    case factoryReset

    var authenticationReason: String {
        switch self {
        case .disableAppLock:
            return String(localized: "Authenticate to turn off App Lock")
        case .factoryReset:
            return String(localized: "Authenticate to permanently erase all data")
        }
    }
}

enum SensitiveActionAuthenticator {
    /// Returns `true` only when the user successfully authenticated; `false` on cancel.
    ///
    /// Destructive / security-downgrade actions always allow device passcode fallback,
    /// independent of the user's App Lock passcode-fallback preference. Daily unlock (B4)
    /// honors that setting; disable App Lock and factory reset deliberately override it so
    /// the device owner can still authenticate via device passcode when biometrics fail.
    nonisolated static func confirm(
        action: SensitiveAction,
        using biometricService: any BiometricServiceProtocol
    ) async throws -> Bool {
        try await biometricService.authenticate(
            reason: action.authenticationReason,
            allowPasscodeFallback: true
        )
    }
}
