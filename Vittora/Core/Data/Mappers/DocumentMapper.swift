import Foundation
import SwiftData

enum DocumentMapper {
    static func toEntity(_ model: SDDocument) -> DocumentEntity {
        DocumentEntity(
            id: model.id,
            fileName: model.fileName,
            mimeType: model.mimeType,
            thumbnailData: model.thumbnailData,
            transactionID: model.transactionID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func updateModel(_ model: SDDocument, from entity: DocumentEntity) {
        model.fileName = entity.fileName
        model.mimeType = entity.mimeType
        model.thumbnailData = entity.thumbnailData
        model.transactionID = entity.transactionID
        model.updatedAt = .now
    }
}
