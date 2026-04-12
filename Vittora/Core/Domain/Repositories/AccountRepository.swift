import Foundation

protocol AccountRepository: Sendable {
    func fetchAll() async throws -> [AccountEntity]
    func fetchByID(_ id: UUID) async throws -> AccountEntity?
    func create(_ entity: AccountEntity) async throws
    func update(_ entity: AccountEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchByType(_ type: AccountType) async throws -> [AccountEntity]
}
