import Foundation

public struct DocumentEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var fileName: String
    public nonisolated var mimeType: String
    public nonisolated var thumbnailData: Data?
    public nonisolated var transactionID: UUID?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
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
