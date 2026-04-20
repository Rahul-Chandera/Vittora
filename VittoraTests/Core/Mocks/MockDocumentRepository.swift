import Foundation
@testable import Vittora

@MainActor
final class MockDocumentRepository: DocumentRepository {
    private(set) var documents: [DocumentEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [DocumentEntity] {
        if shouldThrowError { throw throwError }
        return documents
    }

    func fetchByID(_ id: UUID) async throws -> DocumentEntity? {
        if shouldThrowError { throw throwError }
        return documents.first { $0.id == id }
    }

    func create(_ entity: DocumentEntity) async throws {
        if shouldThrowError { throw throwError }
        documents.append(entity)
    }

    func update(_ entity: DocumentEntity) async throws {
        if shouldThrowError { throw throwError }
        guard let index = documents.firstIndex(where: { $0.id == entity.id }) else {
            throw VittoraError.notFound(String(localized: "Document not found"))
        }
        documents[index] = entity
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        guard let index = documents.firstIndex(where: { $0.id == id }) else {
            throw VittoraError.notFound(String(localized: "Document not found"))
        }
        documents.remove(at: index)
    }

    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity] {
        if shouldThrowError { throw throwError }
        return documents.filter { $0.transactionID == transactionID }
    }

    func seed(_ entity: DocumentEntity) {
        documents.append(entity)
    }
}

@MainActor
final class MockDocumentStorageService: DocumentStorageServiceProtocol {
    private(set) var savedDocuments: [UUID: Data] = [:]
    private(set) var savedThumbnails: [UUID: Data] = [:]
    private(set) var deletedDocuments: [UUID] = []
    private(set) var deletedThumbnails: [UUID] = []
    var shouldThrowError = false
    var errorToThrow: Error = DocumentError.storageUnavailable

    func saveDocument(_ data: Data, for entity: DocumentEntity) async throws {
        if shouldThrowError { throw errorToThrow }
        savedDocuments[entity.id] = data
    }

    func loadDocument(for entity: DocumentEntity) async throws -> Data {
        if shouldThrowError { throw errorToThrow }
        guard let data = savedDocuments[entity.id] else {
            throw DocumentError.fileNotFound
        }
        return data
    }

    func deleteDocument(for entity: DocumentEntity) async throws {
        if shouldThrowError { throw errorToThrow }
        deletedDocuments.append(entity.id)
        savedDocuments.removeValue(forKey: entity.id)
    }

    func saveThumbnail(_ data: Data, for documentID: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        savedThumbnails[documentID] = data
    }

    func loadThumbnail(for documentID: UUID) async throws -> Data? {
        if shouldThrowError { throw errorToThrow }
        return savedThumbnails[documentID]
    }

    func deleteThumbnail(for documentID: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        deletedThumbnails.append(documentID)
        savedThumbnails.removeValue(forKey: documentID)
    }
}
