import Foundation

struct MockTransactionRepository: TransactionRepository {
    func fetchTransactionCount() async throws -> Int {
        try await fetchAll(filter: nil).count
    }

    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        let now = Date()
        return [
            TransactionEntity(
                id: UUID(),
                amount: 50,
                date: now,
                note: "Grocery Shopping",
                type: .expense
            ),
            TransactionEntity(
                id: UUID(),
                amount: 25,
                date: now.addingTimeInterval(-86400),
                note: "Coffee",
                type: .expense
            ),
            TransactionEntity(
                id: UUID(),
                amount: 100,
                date: now.addingTimeInterval(-86400 * 2),
                note: "Lunch",
                type: .expense
            ),
        ]
    }

    func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        return TransactionEntity(
            id: id,
            amount: 50,
            date: Date(),
            note: "Sample",
            type: .expense
        )
    }

    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity] {
        try await fetchAll(filter: nil)
            .filter { $0.recurringRuleID == id }
            .sorted { $0.date > $1.date }
    }

    func hasTransactions(forAccountID id: UUID) async throws -> Bool {
        try await fetchAll(filter: nil)
            .contains { $0.accountID == id || $0.destinationAccountID == id }
    }

    func create(_ entity: TransactionEntity) async throws {}

    func update(_ entity: TransactionEntity) async throws {}

    func delete(_ id: UUID) async throws {}

    func bulkDelete(_ ids: [UUID]) async throws {}

    func search(query: String) async throws -> [TransactionEntity] {
        return try await fetchAll(filter: nil)
    }
}
