import Foundation
import SwiftData

@ModelActor
actor SwiftDataDocumentRepository: DocumentRepository {
    func fetchAll() async throws -> [DocumentEntity] {
        let descriptor = FetchDescriptor<SDDocument>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(DocumentMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> DocumentEntity? {
        let descriptor = FetchDescriptor<SDDocument>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return DocumentMapper.toEntity(model)
    }

    func create(_ entity: DocumentEntity) async throws {
        if let thumb = entity.thumbnailData {
            try DocumentMapper.saveThumbnail(thumb, for: entity.id)
        }
        let model = SDDocument(
            id: entity.id,
            fileName: entity.fileName,
            mimeType: entity.mimeType,
            transactionID: entity.transactionID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ entity: DocumentEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDDocument>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Document not found"))
        }
        if let thumb = entity.thumbnailData {
            try DocumentMapper.saveThumbnail(thumb, for: entity.id)
        } else {
            try DocumentMapper.deleteThumbnail(for: entity.id)
        }
        DocumentMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDDocument>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Document not found"))
        }
        try DocumentMapper.deleteThumbnail(for: id)
        modelContext.delete(model)
        try modelContext.save()
    }

    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity] {
        let capturedTransactionID = transactionID
        let descriptor = FetchDescriptor<SDDocument>(
            predicate: #Predicate { $0.transactionID == capturedTransactionID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(DocumentMapper.toEntity)
    }
}
