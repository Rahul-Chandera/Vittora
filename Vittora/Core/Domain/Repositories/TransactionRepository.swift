import Foundation

protocol TransactionRepository: Sendable {
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity]
    func fetchByID(_ id: UUID) async throws -> TransactionEntity?
    func create(_ entity: TransactionEntity) async throws
    func update(_ entity: TransactionEntity) async throws
    func delete(_ id: UUID) async throws
    func bulkDelete(_ ids: [UUID]) async throws
    func search(query: String) async throws -> [TransactionEntity]
}
