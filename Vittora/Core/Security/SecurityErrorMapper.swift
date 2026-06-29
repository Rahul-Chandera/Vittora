import Foundation
import Security
import VittoraCore

/// Context for mapping platform security failures to user-safe messages (SECURITY-12 / B7).
enum SecurityErrorContext: Sendable {
    case keychainSave
    case keychainLoad
    case keychainDelete
    case keychainAccessControl
    case secureEnclaveSetup
    case secureEnclaveWrap
    case secureEnclaveUnwrap
    case secureEnclavePublicKey
    case legacyKeyMigration
    case keyRetrieval
    case decrypt
    case encrypt
}

enum SecurityErrorMapper {
    nonisolated static func userMessage(for context: SecurityErrorContext) -> String {
        switch context {
        case .keychainSave, .keychainLoad, .keychainDelete, .keychainAccessControl:
            String(localized: "Unable to access secure storage. Please try again.")
        case .secureEnclaveSetup, .secureEnclavePublicKey:
            String(localized: "Unable to set up secure encryption. Please try again.")
        case .secureEnclaveWrap, .secureEnclaveUnwrap, .legacyKeyMigration, .keyRetrieval:
            String(localized: "Unable to access encrypted data. Please authenticate and try again.")
        case .decrypt, .encrypt:
            String(localized: "Unable to process encrypted data. Please try again.")
        }
    }

    nonisolated static func encryptionFailed(
        _ context: SecurityErrorContext,
        osStatus: OSStatus? = nil,
        cfError: CFError? = nil,
        underlying: Error? = nil,
        key: String? = nil
    ) -> VittoraError {
        if let osStatus {
            logOSStatus(osStatus, context: context, key: key)
        }
        if let cfError {
            logCFError(cfError, context: context)
        }
        if let underlying {
            logUnderlying(underlying, context: context)
        }
        return .encryptionFailed(userMessage(for: context))
    }

    nonisolated static func logOSStatus(
        _ status: OSStatus,
        context: SecurityErrorContext,
        key: String? = nil
    ) {
        var message = "context=\(context) status=\(status)"
        if let key { message += " key=\(key)" }
        PerformanceLogger.Security.platformFailure(message)
    }

    nonisolated static func logCFError(_ error: CFError?, context: SecurityErrorContext) {
        let detail: String
        if let error {
            detail = (CFErrorCopyDescription(error) as String?) ?? String(describing: error)
        } else {
            detail = "nil"
        }
        PerformanceLogger.Security.platformFailure("context=\(context) cfError=\(detail)")
    }

    nonisolated static func logUnderlying(_ error: Error, context: SecurityErrorContext) {
        PerformanceLogger.Security.platformFailure("context=\(context) error=\(error.localizedDescription)")
    }
}
