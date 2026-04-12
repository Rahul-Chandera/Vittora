import Foundation

struct FetchTransactionsUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        return try await transactionRepository.fetchAll(filter: filter)
    }

    func executePaginated(
        filter: TransactionFilter?,
        offset: Int,
        limit: Int
    ) async throws -> [TransactionEntity] {
        let allTransactions = try await transactionRepository.fetchAll(filter: filter)
        let endIndex = min(offset + limit, allTransactions.count)

        guard offset < allTransactions.count else {
            return []
        }

        return Array(allTransactions[offset..<endIndex])
    }

    func executeGroupedByDate(filter: TransactionFilter?) async throws -> [(date: Date, transactions: [TransactionEntity])] {
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        // Group by calendar day
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }

        // Sort by date descending and return as array of tuples
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            (date: date, transactions: grouped[date] ?? [])
        }
    }
}
