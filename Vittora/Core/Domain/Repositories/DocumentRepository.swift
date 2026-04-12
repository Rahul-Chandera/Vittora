import Foundation

protocol DocumentRepository: Sendable {
    func fetchAll() async throws -> [DocumentEntity]
    func fetchByID(_ id: UUID) async throws -> DocumentEntity?
    func create(_ entity: DocumentEntity) async throws
    func update(_ entity: DocumentEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity]
}
