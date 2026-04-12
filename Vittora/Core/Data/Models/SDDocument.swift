import Foundation
import SwiftData

@Model
final class SDDocument {
    var id: UUID = UUID()
    var fileName: String = ""
    var mimeType: String = "image/jpeg"
    var thumbnailData: Data?
    var fileData: Data?
    var encryptedData: Data?
    var transactionID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String = "image/jpeg",
        thumbnailData: Data? = nil,
        fileData: Data? = nil,
        encryptedData: Data? = nil,
        transactionID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.thumbnailData = thumbnailData
        self.fileData = fileData
        self.encryptedData = encryptedData
        self.transactionID = transactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
