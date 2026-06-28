import Foundation

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
