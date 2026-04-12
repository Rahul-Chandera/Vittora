import Foundation

struct PayeeAnalyticsUseCase: Sendable {
    private let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(payeeID: UUID) async throws -> PayeeAnalytics {
        let filter = TransactionFilter(payeeIDs: [payeeID])
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        let expenses = transactions.filter { $0.type == .expense }
        let totalSpent = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let count = expenses.count
        let average = count > 0 ? totalSpent / Decimal(count) : Decimal(0)
        let lastDate = expenses.map(\.date).max()

        return PayeeAnalytics(
            payeeID: payeeID,
            totalSpent: totalSpent,
            transactionCount: count,
            averageAmount: average,
            lastTransactionDate: lastDate
        )
    }
}
