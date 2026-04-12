import Foundation
@testable import Vittora

actor MockTransactionRepository: TransactionRepository {
    private(set) var transactions: [TransactionEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        var results = transactions
        if let filter = filter {
            if let startDate = filter.startDate {
                results = results.filter { $0.date >= startDate }
            }
            if let endDate = filter.endDate {
                results = results.filter { $0.date <= endDate }
            }
            if let categoryID = filter.categoryID {
                results = results.filter { $0.categoryID == categoryID }
            }
            if let accountID = filter.accountID {
                results = results.filter { $0.accountID == accountID }
            }
            if let type = filter.transactionType {
                results = results.filter { $0.type == type }
            }
        }
        return results.sorted { $0.date > $1.date }
    }

    func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        if shouldThrowError { throw throwError }
        return transactions.first { $0.id == id }
    }

    func create(_ entity: TransactionEntity) async throws {
        if shouldThrowError { throw throwError }
        transactions.append(entity)
    }

    func update(_ entity: TransactionEntity) async throws {
        if shouldThrowError { throw throwError }
        if let index = transactions.firstIndex(where: { $0.id == entity.id }) {
            transactions[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        if let index = transactions.firstIndex(where: { $0.id == id }) {
            transactions.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }
    }

    func bulkDelete(_ ids: [UUID]) async throws {
        if shouldThrowError { throw throwError }
        for id in ids {
            try await delete(id)
        }
    }

    func search(query: String) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        return transactions.filter { ($0.note ?? "").localizedStandardContains(query) }
    }
}
