import Foundation

@Observable @MainActor final class TransactionDetailViewModel {
    var transaction: TransactionEntity?
    var relatedTransactions: [TransactionEntity] = []
    var isLoading = false
    var error: String?

    private let fetchUseCase: FetchTransactionsUseCase
    private let deleteUseCase: DeleteTransactionUseCase

    init(
        fetchUseCase: FetchTransactionsUseCase,
        deleteUseCase: DeleteTransactionUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
    }

    func loadTransaction(id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let transactions = try await fetchUseCase.execute(filter: nil)
            guard let found = transactions.first(where: { $0.id == id }) else {
                error = "Transaction not found"
                return
            }
            transaction = found

            // Load related transactions (same payee, same account, within 30 days)
            if let payeeID = found.payeeID, let accountID = found.accountID {
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: found.date) ?? found.date
                let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: found.date) ?? found.date
                let dateRange = thirtyDaysAgo...thirtyDaysLater

                let filter = TransactionFilter(
                    dateRange: dateRange,
                    accountIDs: [accountID],
                    payeeIDs: [payeeID]
                )
                let related = try await fetchUseCase.execute(filter: filter)
                relatedTransactions = related.filter { $0.id != id }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete() async throws {
        guard let transaction = transaction else {
            throw VittoraError.notFound("Transaction not found")
        }
        try await deleteUseCase.execute(id: transaction.id)
        self.transaction = nil
    }

    func duplicate() async throws -> TransactionEntity {
        guard let transaction = transaction else {
            throw VittoraError.notFound("Transaction not found")
        }

        return TransactionEntity(
            id: UUID(),
            amount: transaction.amount,
            date: .now,
            note: transaction.note,
            type: transaction.type,
            paymentMethod: transaction.paymentMethod,
            currencyCode: transaction.currencyCode,
            tags: transaction.tags,
            categoryID: transaction.categoryID,
            accountID: transaction.accountID,
            payeeID: transaction.payeeID,
            destinationAccountID: transaction.destinationAccountID,
            recurringRuleID: transaction.recurringRuleID,
            documentIDs: transaction.documentIDs,
            createdAt: .now,
            updatedAt: .now
        )
    }
}
