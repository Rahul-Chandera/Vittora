import Foundation
import OSLog
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import VittoraCore
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
        // PDFs reach here from multi-page scans and from file import. Both used to
        // get no thumbnail at all and fell back to a generic file icon, so a list of
        // PDF receipts was unidentifiable. Render page 1 instead.
        if mimeType == "application/pdf" {
            return pdfFirstPageThumbnail(from: data)
        }
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

    /// Page 1 rendered at thumbnail size. `thumbnailData` is stored on the entity
    /// and synced, so this stays small rather than rendering at page resolution.
    private func pdfFirstPageThumbnail(from data: Data) -> Data? {
        #if canImport(PDFKit)
        guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        let size = CGSize(width: 120, height: 120)
        #if canImport(UIKit)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.7) { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // thumbnail(of:for:) aspect-fits the page into the box for us.
            page.thumbnail(of: size, for: .mediaBox).draw(in: CGRect(origin: .zero, size: size))
        }
        #elseif canImport(AppKit)
        return page.thumbnail(of: size, for: .mediaBox).tiffRepresentation
        #else
        return nil
        #endif
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
