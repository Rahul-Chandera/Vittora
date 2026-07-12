import Foundation
import SwiftData

@Model
public final class SDDocument {
    #Index<SDDocument>([\.transactionID])

    public var id: UUID = UUID()
    public var fileName: String = ""
    public var mimeType: String = "image/jpeg"
    public var transactionID: UUID?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
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
