import Foundation

struct FetchTransactionsUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        return try await transactionRepository.fetchAll(filter: filter)
    }

    func executeGroupedByDate(filter: TransactionFilter?) async throws -> [(date: Date, transactions: [TransactionEntity])] {
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        // Group by calendar day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        // Sort by date descending and return as array of tuples
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            (date: date, transactions: grouped[date] ?? [])
        }
    }
}
