import Foundation

struct FetchTransactionsUseCase: Sendable {
    static let listPageSize = 50

    let transactionRepository: any TransactionRepository

    nonisolated init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        return try await transactionRepository.fetchAll(filter: filter)
    }

    func executePage(
        filter: TransactionFilter?,
        offset: Int,
        limit: Int = listPageSize
    ) async throws -> [TransactionEntity] {
        try await transactionRepository.fetchPage(filter: filter, offset: offset, limit: limit)
    }

    func execute(id: UUID) async throws -> TransactionEntity? {
        try await transactionRepository.fetchByID(id)
    }

    func executeGroupedByDate(filter: TransactionFilter?) async throws -> [(date: Date, transactions: [TransactionEntity])] {
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        return Self.groupByDate(transactions)
    }

    static func groupByDate(
        _ transactions: [TransactionEntity]
    ) -> [(date: Date, transactions: [TransactionEntity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            (date: date, transactions: grouped[date] ?? [])
        }
    }

    static func mergeGrouped(
        _ existing: [(date: Date, transactions: [TransactionEntity])],
        with newTransactions: [TransactionEntity]
    ) -> [(date: Date, transactions: [TransactionEntity])] {
        var byDate: [Date: [TransactionEntity]] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.date, $0.transactions) }
        )
        let calendar = Calendar.current
        for transaction in newTransactions {
            let day = calendar.startOfDay(for: transaction.date)
            byDate[day, default: []].append(transaction)
        }
        return byDate.keys.sorted(by: >).map { date in
            (date: date, transactions: byDate[date] ?? [])
        }
    }
}
