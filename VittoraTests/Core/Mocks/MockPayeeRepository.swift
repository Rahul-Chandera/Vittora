import Foundation
@testable import Vittora

actor MockPayeeRepository: PayeeRepository {
    private(set) var payees: [PayeeEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [PayeeEntity] {
        if shouldThrowError { throw throwError }
        return payees.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fetchByID(_ id: UUID) async throws -> PayeeEntity? {
        if shouldThrowError { throw throwError }
        return payees.first { $0.id == id }
    }

    func create(_ entity: PayeeEntity) async throws {
        if shouldThrowError { throw throwError }
        payees.append(entity)
    }

    func update(_ entity: PayeeEntity) async throws {
        if shouldThrowError { throw throwError }
        if let index = payees.firstIndex(where: { $0.id == entity.id }) {
            payees[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        if let index = payees.firstIndex(where: { $0.id == id }) {
            payees.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
    }

    func search(query: String) async throws -> [PayeeEntity] {
        if shouldThrowError { throw throwError }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func fetchFrequent(limit: Int) async throws -> [PayeeEntity] {
        if shouldThrowError { throw throwError }
        return Array(payees.prefix(limit))
    }

    // Test helpers
    func seed(_ entity: PayeeEntity) {
        payees.append(entity)
    }

    func seedMany(_ entities: [PayeeEntity]) {
        payees.append(contentsOf: entities)
    }
}
