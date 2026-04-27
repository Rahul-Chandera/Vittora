import Foundation

protocol DocumentRepository: Sendable {
    func fetchAll() async throws -> [DocumentEntity]
    func fetchCount() async throws -> Int
    func fetchByID(_ id: UUID) async throws -> DocumentEntity?
    func create(_ entity: DocumentEntity) async throws
    func update(_ entity: DocumentEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity]
}

protocol DocumentStorageServiceProtocol: Sendable {
    func saveDocument(_ data: Data, for entity: DocumentEntity) async throws
    func loadDocument(for entity: DocumentEntity) async throws -> Data
    func deleteDocument(for entity: DocumentEntity) async throws
    func saveThumbnail(_ data: Data, for documentID: UUID) async throws
    func loadThumbnail(for documentID: UUID) async throws -> Data?
    func deleteThumbnail(for documentID: UUID) async throws
}
