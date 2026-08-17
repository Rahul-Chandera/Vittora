import Foundation
import VittoraCore

@Observable @MainActor final class TransactionDetailViewModel {
    var transaction: TransactionEntity?
    var relatedTransactions: [TransactionEntity] = []
    var editHistory: [TransactionEditRecord] = []
    /// Resolved names for the transaction's category and account. The detail
    /// screen showed neither, so you could not tell what a transaction was
    /// filed under or which account it came out of.
    var categoryName: String?
    var accountName: String?
    var isLoading = false
    var error: String?

    private let fetchUseCase: FetchTransactionsUseCase
    private let deleteUseCase: DeleteTransactionUseCase
    private let editHistoryStore: any TransactionEditHistoryStoring
    private let categoryRepository: any CategoryRepository
    private let accountRepository: any AccountRepository

    init(
        fetchUseCase: FetchTransactionsUseCase,
        deleteUseCase: DeleteTransactionUseCase,
        editHistoryStore: any TransactionEditHistoryStoring,
        categoryRepository: any CategoryRepository,
        accountRepository: any AccountRepository
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
        self.editHistoryStore = editHistoryStore
        self.categoryRepository = categoryRepository
        self.accountRepository = accountRepository
    }

    func loadTransaction(id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            guard let found = try await fetchUseCase.execute(id: id) else {
                error = String(localized: "We couldn't find this transaction.")
                editHistory = []
                return
            }
            transaction = found
            editHistory = (try? editHistoryStore.fetch(for: id)) ?? []

            // Names are resolved here rather than in the view so a missing
            // category or account simply hides its row instead of showing a
            // raw UUID or an empty label.
            if let categoryID = found.categoryID {
                categoryName = try? await categoryRepository.fetchByID(categoryID)?.name
            } else {
                categoryName = nil
            }
            if let accountID = found.accountID {
                accountName = try? await accountRepository.fetchByID(accountID)?.name
            } else {
                accountName = nil
            }

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
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load this transaction right now.")
            )
        }
    }

    func delete() async throws {
        guard let transaction = transaction else {
            throw VittoraError.notFound(String(localized: "Transaction"))
        }
        try await deleteUseCase.execute(id: transaction.id)
        self.transaction = nil
        editHistory = []
    }

    func duplicate() async throws -> TransactionEntity {
        guard let transaction = transaction else {
            throw VittoraError.notFound(String(localized: "Transaction"))
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
