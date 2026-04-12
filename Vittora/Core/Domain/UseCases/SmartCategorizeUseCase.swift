import Foundation

struct SmartCategorizeUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(payeeID: UUID?, amount: Decimal) async throws -> UUID? {
        // Return nil if no payeeID provided
        guard let payeeID = payeeID else {
            return nil
        }

        // Fetch all transactions with this payee
        let filter = TransactionFilter(payeeIDs: [payeeID])
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        // Filter for transactions with non-nil categoryID
        let categorizedTransactions = transactions.filter { $0.categoryID != nil }

        guard !categorizedTransactions.isEmpty else {
            return nil
        }

        // Find the most frequent categoryID
        let categoryCounts = Dictionary(grouping: categorizedTransactions, by: { $0.categoryID })
            .mapValues { $0.count }

        if let mostFrequentCategory = categoryCounts.max(by: { $0.value < $1.value })?.key {
            return mostFrequentCategory
        }

        return nil
    }
}
