import Foundation

struct TransferFundsUseCase: Sendable {
    let accountRepository: any AccountRepository
    /// REQUIRED, non-optional: money writes must be atomic. Routing through the
    /// ledger store guarantees both legs + both balance adjustments persist in a
    /// single save (or not at all). There is no non-atomic repository fallback.
    ///
    /// Pre-I1: callers unwrap the optional vended store-or-throw at construction.
    /// Post-A6 follow-up: switch this to `any LedgerWriting` once that seam lands.
    let ledgerWriteStore: LedgerWriteStore

    nonisolated init(
        accountRepository: any AccountRepository,
        ledgerWriteStore: LedgerWriteStore
    ) {
        self.accountRepository = accountRepository
        self.ledgerWriteStore = ledgerWriteStore
    }

    func execute(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date = .now,
        note: String = "",
        currencyCode: String = CurrencyDefaults.code
    ) async throws {
        guard sourceAccountID != destinationAccountID else {
            throw VittoraError.validationFailed(
                String(localized: "Source and destination accounts must be different")
            )
        }

        guard let sourceAccount = try await accountRepository.fetchByID(sourceAccountID) else {
            throw VittoraError.notFound(String(localized: "Source account not found"))
        }
        guard let destinationAccount = try await accountRepository.fetchByID(destinationAccountID) else {
            throw VittoraError.notFound(String(localized: "Destination account not found"))
        }

        guard !sourceAccount.isArchived else {
            throw VittoraError.validationFailed(
                String(localized: "Cannot transfer from an archived account")
            )
        }
        guard !destinationAccount.isArchived else {
            throw VittoraError.validationFailed(
                String(localized: "Cannot transfer to an archived account")
            )
        }

        guard amount > 0 else {
            throw VittoraError.validationFailed(
                String(localized: "Transfer amount must be positive")
            )
        }

        // Two paired legs (debit source, credit destination) + both balance
        // adjustments persist atomically in one save inside the ledger store.
        try await ledgerWriteStore.performTransfer(
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            amount: amount,
            date: date,
            note: note,
            currencyCode: currencyCode
        )
    }
}
