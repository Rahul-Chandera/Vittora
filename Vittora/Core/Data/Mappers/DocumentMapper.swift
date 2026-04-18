import Foundation
import SwiftData

enum DocumentMapper {
    nonisolated static func toEntity(_ model: SDDocument) -> DocumentEntity {
        DocumentEntity(
            id: model.id,
            fileName: model.fileName,
            mimeType: model.mimeType,
            thumbnailData: loadThumbnail(for: model.id),
            transactionID: model.transactionID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDDocument, from entity: DocumentEntity) {
        model.fileName = entity.fileName
        model.mimeType = entity.mimeType
        model.transactionID = entity.transactionID
        model.updatedAt = .now
    }

    // MARK: - Filesystem thumbnail helpers

    /// Returns the .completeFileProtection URL for a document's thumbnail.
    nonisolated static func thumbnailURL(for id: UUID) -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("\(id.uuidString)_thumb.jpg")
    }

    nonisolated static func saveThumbnail(_ data: Data, for id: UUID) throws {
        guard let url = thumbnailURL(for: id) else { return }
        try data.write(to: url, options: .completeFileProtection)
    }

    nonisolated static func deleteThumbnail(for id: UUID) {
        guard let url = thumbnailURL(for: id) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private nonisolated static func loadThumbnail(for id: UUID) -> Data? {
        guard let url = thumbnailURL(for: id) else { return nil }
        return try? Data(contentsOf: url)
    }
}
