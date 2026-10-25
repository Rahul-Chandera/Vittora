import Foundation
import VittoraCore

/// Turns queued expenses into real transactions: widget taps (M2.7.5) and the Log
/// Expense Shortcuts actions.
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
    /// Matches a queued merchant name to a payee. Nil in the widget-only tests.
    let payeeRepository: (any PayeeRepository)?
    /// Fills in a category when the entry has none: the user's rules, then payee history.
    let categorize: SmartCategorizeUseCase?

    nonisolated init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        queue: QuickLogQueue,
        payeeRepository: (any PayeeRepository)? = nil,
        categorize: SmartCategorizeUseCase? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.queue = queue
        self.payeeRepository = payeeRepository
        self.categorize = categorize
    }

    /// Returns how many entries became transactions.
    @discardableResult
    func execute() async throws -> Int {
        let entries = queue.pending()
        guard !entries.isEmpty else { return 0 }

        // Without an account there is nothing to book against. Entries are left in the
        // queue rather than dropped, so they land once the user has set an account up.
        guard let account = try await defaultAccount() else { return 0 }

        let payees = entries.contains { $0.payeeName != nil }
            ? (try await payeeRepository?.fetchAll() ?? [])
            : []

        var committed = 0
        for entry in entries {
            let payeeID = Self.matchingPayee(named: entry.payeeName, in: payees)?.id
            // A merchant with no matching payee stays visible in the note rather than
            // creating payees from whatever text a card alert happened to contain.
            let note = payeeID == nil
                ? [entry.payeeName, entry.note].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
                : entry.note
            var categoryID = try await resolvedCategoryID(entry.categoryID)
            if categoryID == nil, entry.payeeName != nil || entry.note != nil {
                categoryID = try? await categorize?.execute(SmartCategorizeRequest(
                    payeeID: payeeID, payeeName: entry.payeeName, note: entry.note, amount: entry.amount
                ))
            }
            let transaction = TransactionEntity(
                amount: entry.amount,
                date: entry.createdAt,
                note: note,
                type: .expense,
                paymentMethod: entry.paymentMethod.flatMap(PaymentMethod.init(rawValue:)) ?? .cash,
                currencyCode: entry.currencyCode ?? CurrencyDefaults.code,
                categoryID: categoryID,
                accountID: account.id,
                payeeID: payeeID
            )
            try await transactionRepository.create(transaction)
            queue.remove(id: entry.id)
            committed += 1
        }
        return committed
    }

    /// Exact name match, ignoring case and surrounding spaces.
    nonisolated static func matchingPayee(named name: String?, in payees: [PayeeEntity]) -> PayeeEntity? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return payees.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
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

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
