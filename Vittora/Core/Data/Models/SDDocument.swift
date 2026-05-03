import Foundation
import SwiftData

@Model
final class SDDocument {
    #Index<SDDocument>([\.transactionID])

    var id: UUID = UUID()
    var fileName: String = ""
    var mimeType: String = "image/jpeg"
    var transactionID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String = "image/jpeg",
        transactionID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.transactionID = transactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
