import Foundation

public protocol TransactionRepository: Sendable {
    /// Total persisted rows (not subject to fetch limits).
    func fetchTransactionCount() async throws -> Int
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity]
    /// Paged fetch ordered by date descending. Used for list pagination and streamed export.
    func fetchPage(filter: TransactionFilter?, offset: Int, limit: Int) async throws -> [TransactionEntity]
    /// All rows with NO fetch cap, for the balance-reconciliation pass
    /// (DATAINTEGRITY-12). Unlike `fetchAll`, this must not silently truncate,
    /// or reconciliation would reason over partial sums.
    func fetchAllForReconciliation() async throws -> [TransactionEntity]
    func fetchByID(_ id: UUID) async throws -> TransactionEntity?
    func fetchForAccount(id: UUID, limit: Int) async throws -> [TransactionEntity]
    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity]
    func hasTransactions(forAccountID id: UUID) async throws -> Bool
    func create(_ entity: TransactionEntity) async throws
    func update(_ entity: TransactionEntity) async throws
    func delete(_ id: UUID) async throws
    func bulkDelete(_ ids: [UUID]) async throws
    func search(query: String) async throws -> [TransactionEntity]
    /// External IDs already in the ledger that start with `prefix` — how an
    /// import (M3.7.1) skips rows it brought in before, whichever account
    /// they have since been moved to.
    func fetchExternalIDs(withPrefix prefix: String) async throws -> Set<String>
}

public extension TransactionRepository {
    /// Unindexed fallback for test doubles; the SwiftData repository filters
    /// in the store.
    func fetchExternalIDs(withPrefix prefix: String) async throws -> Set<String> {
        Set(try await fetchAllForReconciliation().compactMap(\.externalID).filter { $0.hasPrefix(prefix) })
    }
}
