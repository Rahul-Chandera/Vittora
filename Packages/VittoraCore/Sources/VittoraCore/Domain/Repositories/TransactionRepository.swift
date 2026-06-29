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
}
