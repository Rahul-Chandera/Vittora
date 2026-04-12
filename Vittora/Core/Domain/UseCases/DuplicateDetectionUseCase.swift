import Foundation

struct DuplicateDetectionUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func execute(
        amount: Decimal,
        date: Date,
        payeeID: UUID?,
        accountID: UUID?
    ) async throws -> [TransactionEntity] {
        // Build date range: 24 hours around the given date
        let startDate = Calendar.current.date(byAdding: .hour, value: -12, to: date) ?? date
        let endDate = Calendar.current.date(byAdding: .hour, value: 12, to: date) ?? date
        let dateRange = startDate...endDate

        // Build filter with all criteria
        var accountIDs: Set<UUID>? = nil
        if let accountID = accountID {
            accountIDs = [accountID]
        }

        var payeeIDs: Set<UUID>? = nil
        if let payeeID = payeeID {
            payeeIDs = [payeeID]
        }

        let filter = TransactionFilter(
            dateRange: dateRange,
            accountIDs: accountIDs,
            payeeIDs: payeeIDs,
            amountRange: amount...amount
        )

        let transactions = try await transactionRepository.fetchAll(filter: filter)

        // Filter for exact matches on amount, date, payeeID, and accountID
        return transactions.filter { transaction in
            transaction.amount == amount &&
            Calendar.current.isDate(transaction.date, inSameDayAs: date) &&
            transaction.payeeID == payeeID &&
            transaction.accountID == accountID
        }
    }
}
