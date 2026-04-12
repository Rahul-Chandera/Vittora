import Foundation

struct DocumentEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var fileName: String
    var mimeType: String
    var thumbnailData: Data?
    var transactionID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
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
