import Foundation

protocol PayeeRepository: Sendable {
    func fetchAll() async throws -> [PayeeEntity]
    func fetchByID(_ id: UUID) async throws -> PayeeEntity?
    func create(_ entity: PayeeEntity) async throws
    func update(_ entity: PayeeEntity) async throws
    func delete(_ id: UUID) async throws
    func search(query: String) async throws -> [PayeeEntity]
    func fetchFrequent(limit: Int) async throws -> [PayeeEntity]
}
