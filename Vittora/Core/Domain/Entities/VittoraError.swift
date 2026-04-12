import Foundation

enum VittoraError: LocalizedError, Sendable {
    case notFound(String)
    case duplicateEntry(String)
    case validationFailed(String)
    case encryptionFailed(String)
    case biometricFailed(String)
    case syncFailed(String)
    case exportFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let detail):
            String(localized: "Not found: \(detail)")
        case .duplicateEntry(let detail):
            String(localized: "Duplicate entry: \(detail)")
        case .validationFailed(let detail):
            String(localized: "Validation failed: \(detail)")
        case .encryptionFailed(let detail):
            String(localized: "Encryption error: \(detail)")
        case .biometricFailed(let detail):
            String(localized: "Authentication error: \(detail)")
        case .syncFailed(let detail):
            String(localized: "Sync error: \(detail)")
        case .exportFailed(let detail):
            String(localized: "Export error: \(detail)")
        case .unknown(let detail):
            String(localized: "An error occurred: \(detail)")
        }
    }
}
