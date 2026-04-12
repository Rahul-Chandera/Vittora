import Foundation
@testable import Vittora

actor MockAccountRepository: AccountRepository {
    private(set) var accounts: [AccountEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [AccountEntity] {
        if shouldThrowError { throw throwError }
        return accounts.sorted { $0.name < $1.name }
    }

    func fetchByID(_ id: UUID) async throws -> AccountEntity? {
        if shouldThrowError { throw throwError }
        return accounts.first { $0.id == id }
    }

    func create(_ entity: AccountEntity) async throws {
        if shouldThrowError { throw throwError }
        accounts.append(entity)
    }

    func update(_ entity: AccountEntity) async throws {
        if shouldThrowError { throw throwError }
        if let index = accounts.firstIndex(where: { $0.id == entity.id }) {
            accounts[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Account not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Account not found"))
        }
    }

    func fetchByType(_ type: AccountType) async throws -> [AccountEntity] {
        if shouldThrowError { throw throwError }
        return accounts.filter { $0.type == type }.sorted { $0.name < $1.name }
    }
}
