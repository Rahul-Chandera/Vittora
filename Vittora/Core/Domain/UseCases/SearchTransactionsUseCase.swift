import Foundation

struct SearchTransactionsUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(query: String) async throws -> [TransactionEntity] {
        // Return empty array if query is empty
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        return try await transactionRepository.search(query: trimmedQuery)
    }
}
