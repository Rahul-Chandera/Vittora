import Foundation

struct DocumentEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var fileName: String
    nonisolated var mimeType: String
    nonisolated var thumbnailData: Data?
    nonisolated var transactionID: UUID?
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String = "image/jpeg",
        thumbnailData: Data? = nil,
        transactionID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.thumbnailData = thumbnailData
        self.transactionID = transactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
