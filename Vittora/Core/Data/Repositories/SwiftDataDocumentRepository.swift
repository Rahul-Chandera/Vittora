import Foundation
import OSLog
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

    func fetchCount() async throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<SDDocument>())
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

@MainActor
final class EncryptedDocumentRepository: DocumentRepository, Sendable {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "documents")
    private let metadataRepository: SwiftDataDocumentRepository
    private let documentStorageService: any DocumentStorageServiceProtocol

    init(
        modelContainer: ModelContainer,
        documentStorageService: any DocumentStorageServiceProtocol
    ) {
        self.metadataRepository = SwiftDataDocumentRepository(modelContainer: modelContainer)
        self.documentStorageService = documentStorageService
    }

    func fetchAll() async throws -> [DocumentEntity] {
        let entities = try await metadataRepository.fetchAll()
        return try await hydrateThumbnails(in: entities)
    }

    func fetchCount() async throws -> Int {
        try await metadataRepository.fetchCount()
    }

    func fetchByID(_ id: UUID) async throws -> DocumentEntity? {
        guard let entity = try await metadataRepository.fetchByID(id) else {
            return nil
        }
        return try await hydrateThumbnail(in: entity)
    }

    func create(_ entity: DocumentEntity) async throws {
        try await metadataRepository.create(strippingThumbnail(from: entity))

        do {
            if let thumbnailData = entity.thumbnailData {
                try await documentStorageService.saveThumbnail(thumbnailData, for: entity.id)
            }
        } catch {
            do {
                try await metadataRepository.delete(entity.id)
            } catch {
                Self.logger.error(
                    "Failed to roll back document metadata after thumbnail save failure: \(error.localizedDescription, privacy: .public)"
                )
            }
            throw error
        }
    }

    func update(_ entity: DocumentEntity) async throws {
        try await metadataRepository.update(strippingThumbnail(from: entity))

        if let thumbnailData = entity.thumbnailData {
            try await documentStorageService.saveThumbnail(thumbnailData, for: entity.id)
        } else {
            try await documentStorageService.deleteThumbnail(for: entity.id)
        }
    }

    func delete(_ id: UUID) async throws {
        if let entity = try await metadataRepository.fetchByID(id) {
            try await documentStorageService.deleteDocument(for: entity)
            try await documentStorageService.deleteThumbnail(for: entity.id)
        }
        try await metadataRepository.delete(id)
    }

    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity] {
        let entities = try await metadataRepository.fetchForTransaction(transactionID)
        return try await hydrateThumbnails(in: entities)
    }

    private func hydrateThumbnails(in entities: [DocumentEntity]) async throws -> [DocumentEntity] {
        var hydratedEntities: [DocumentEntity] = []
        hydratedEntities.reserveCapacity(entities.count)

        for entity in entities {
            hydratedEntities.append(try await hydrateThumbnail(in: entity))
        }

        return hydratedEntities
    }

    private func hydrateThumbnail(in entity: DocumentEntity) async throws -> DocumentEntity {
        var hydratedEntity = entity
        hydratedEntity.thumbnailData = try await documentStorageService.loadThumbnail(for: entity.id)
        return hydratedEntity
    }

    private func strippingThumbnail(from entity: DocumentEntity) -> DocumentEntity {
        var metadataOnly = entity
        metadataOnly.thumbnailData = nil
        return metadataOnly
    }
}
