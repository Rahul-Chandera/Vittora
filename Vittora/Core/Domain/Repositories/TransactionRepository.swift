import Foundation

protocol TransactionRepository: Sendable {
    /// Total persisted rows (not subject to fetch limits).
    func fetchTransactionCount() async throws -> Int
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity]
    func fetchByID(_ id: UUID) async throws -> TransactionEntity?
    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity]
    func hasTransactions(forAccountID id: UUID) async throws -> Bool
    func create(_ entity: TransactionEntity) async throws
    func update(_ entity: TransactionEntity) async throws
    func delete(_ id: UUID) async throws
    func bulkDelete(_ ids: [UUID]) async throws
    func search(query: String) async throws -> [TransactionEntity]
}
