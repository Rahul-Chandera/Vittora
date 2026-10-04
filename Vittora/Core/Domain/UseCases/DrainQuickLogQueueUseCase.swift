import Foundation
import VittoraCore

/// Turns widget taps into real transactions (M2.7.5).
///
/// Runs in the app, which is the only process allowed to write the ledger. Each entry is
/// removed only after its transaction is committed: a crash between the two costs a
/// duplicate the user can see and delete, while the other order costs an expense they
/// would never know was lost.
struct DrainQuickLogQueueUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let categoryRepository: any CategoryRepository
    let queue: QuickLogQueue

    nonisolated init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        queue: QuickLogQueue
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.queue = queue
    }

    /// Returns how many entries became transactions.
    @discardableResult
    func execute() async throws -> Int {
        let entries = queue.pending()
        guard !entries.isEmpty else { return 0 }

        // Without an account there is nothing to book against. Entries are left in the
        // queue rather than dropped, so they land once the user has set an account up.
        guard let account = try await defaultAccount() else { return 0 }

        var committed = 0
        for entry in entries {
            let categoryID = try await resolvedCategoryID(entry.categoryID)
            let transaction = TransactionEntity(
                amount: entry.amount,
                date: entry.createdAt,
                note: entry.note,
                type: .expense,
                categoryID: categoryID,
                accountID: account.id
            )
            try await transactionRepository.create(transaction)
            queue.remove(id: entry.id)
            committed += 1
        }
        return committed
    }

    private func defaultAccount() async throws -> AccountEntity? {
        let accounts = try await accountRepository.fetchAll()
        return accounts.first { !$0.isArchived } ?? accounts.first
    }

    /// A category deleted between the tap and the drain must not take the expense with it.
    /// The amount is what matters; an uncategorised transaction is recoverable, a lost one
    /// is not.
    private func resolvedCategoryID(_ categoryID: UUID?) async throws -> UUID? {
        guard let categoryID else { return nil }
        return try await categoryRepository.fetchByID(categoryID) != nil ? categoryID : nil
    }
}
