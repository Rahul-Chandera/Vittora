import Foundation
@testable import Vittora

actor MockTransactionRepository: TransactionRepository {
    private(set) var transactions: [TransactionEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))
    /// When set, simulates repository list caps (e.g. SwiftDataTransactionRepository's 500-row limit).
    var fetchAllLimit: Int?

    func setFetchAllLimit(_ limit: Int?) {
        fetchAllLimit = limit
    }

    func fetchTransactionCount() async throws -> Int {
        if shouldThrowError { throw throwError }
        return transactions.count
    }

    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        var results = transactions
        if let filter {
            if let dateRange = filter.dateRange {
                results = results.filter { dateRange.contains($0.date) }
            }
            if let categoryIDs = filter.categoryIDs {
                results = results.filter { $0.categoryID.map { categoryIDs.contains($0) } ?? false }
            }
            if let accountIDs = filter.accountIDs {
                results = results.filter { $0.accountID.map { accountIDs.contains($0) } ?? false }
            }
            if let types = filter.types {
                results = results.filter { types.contains($0.type) }
            }
            if let query = filter.searchQuery, !query.isEmpty {
                results = results.filter { ($0.note ?? "").localizedStandardContains(query) }
            }
            if let amountRange = filter.amountRange {
                results = results.filter { amountRange.contains($0.amount) }
            }
        }
        let sorted = results.sorted { $0.date > $1.date }
        if let fetchAllLimit {
            return Array(sorted.prefix(fetchAllLimit))
        }
        return sorted
    }

    func fetchPage(filter: TransactionFilter?, offset: Int, limit: Int) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        let savedLimit = fetchAllLimit
        fetchAllLimit = nil
        defer { fetchAllLimit = savedLimit }
        let all = try await fetchAll(filter: filter)
        let start = min(max(0, offset), all.count)
        let end = min(start + max(1, limit), all.count)
        guard start < end else { return [] }
        return Array(all[start..<end])
    }

    func fetchAllForReconciliation() async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        return transactions
    }

    func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        if shouldThrowError { throw throwError }
        return transactions.first { $0.id == id }
    }

    func fetchForAccount(id: UUID, limit: Int) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        let filter = TransactionFilter(accountIDs: [id])
        let results = try await fetchAll(filter: filter)
        return Array(results.prefix(max(1, limit)))
    }

    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity] {
        if shouldThrowError { throw throwError }
        return transactions
            .filter { $0.recurringRuleID == id }
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
    }

    func hasTransactions(forAccountID id: UUID) async throws -> Bool {
        if shouldThrowError { throw throwError }
        return transactions.contains { $0.accountID == id || $0.destinationAccountID == id }
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
