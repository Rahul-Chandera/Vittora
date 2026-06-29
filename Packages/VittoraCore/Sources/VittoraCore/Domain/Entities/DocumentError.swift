import Foundation

public enum DocumentError: LocalizedError, Sendable {
    case storageUnavailable
    case fileNotFound
    case ocrFailed(String)

    public var errorDescription: String? {
        switch self {
        case .storageUnavailable: return String(localized: "Document storage is unavailable.")
        case .fileNotFound:       return String(localized: "Document file not found.")
        case .ocrFailed(let msg): return String(localized: "OCR failed: \(msg)")
        }
    }
}
