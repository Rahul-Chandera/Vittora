import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AttachDocumentUseCase: Sendable {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "documents")
    let documentRepository: any DocumentRepository
    let documentStorageService: any DocumentStorageServiceProtocol

    func execute(
        imageData: Data,
        mimeType: String,
        transactionID: UUID?
    ) async throws -> DocumentEntity {
        let documentID = UUID()
        let fileName = "\(documentID.uuidString).\(fileExtension(for: mimeType))"
        let thumbnailData = generateThumbnail(from: imageData, mimeType: mimeType)

        let entity = DocumentEntity(
            id: documentID,
            fileName: fileName,
            mimeType: mimeType,
            thumbnailData: thumbnailData,
            transactionID: transactionID
        )
        try await documentStorageService.saveDocument(imageData, for: entity)
        do {
            try await documentRepository.create(entity)
        } catch {
            do {
                try await documentStorageService.deleteDocument(for: entity)
            } catch {
                Self.logger.error(
                    "Failed to clean up document bytes after metadata save failure: \(error.localizedDescription, privacy: .public)"
                )
            }
            throw error
        }
        return entity
    }

    // MARK: - Thumbnail generation

    private func generateThumbnail(from data: Data, mimeType: String) -> Data? {
        guard mimeType.hasPrefix("image/") else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data)
            .flatMap { $0.preparingThumbnail(of: CGSize(width: 120, height: 120)) }
            .flatMap { $0.jpegData(compressionQuality: 0.7) }
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        let thumb = NSImage(size: CGSize(width: 120, height: 120))
        thumb.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: CGSize(width: 120, height: 120)))
        thumb.unlockFocus()
        return thumb.tiffRepresentation
        #else
        return nil
        #endif
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png":  return "png"
        case "application/pdf": return "pdf"
        default: return "bin"
        }
    }
}

enum DocumentError: LocalizedError {
    case storageUnavailable
    case fileNotFound
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .storageUnavailable: return String(localized: "Document storage is unavailable.")
        case .fileNotFound:       return String(localized: "Document file not found.")
        case .ocrFailed(let msg): return String(localized: "OCR failed: \(msg)")
        }
    }
}
