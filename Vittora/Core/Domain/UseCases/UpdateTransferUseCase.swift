import Foundation

/// Edits an existing paired transfer end-to-end (A4): it validates the new
/// source/destination/amount and routes the change through
/// `LedgerWriteStore.performUpdateTransfer`, which reverses both old legs and
/// re-applies both new legs atomically (one save).
///
/// This is the dedicated transfer-edit counterpart to `TransferFundsUseCase`.
/// The generic `UpdateTransactionUseCase` deliberately rejects transfer legs
/// (Option B), so transfer edits must come through here.
struct UpdateTransferUseCase: Sendable {
    let accountRepository: any AccountRepository
    /// REQUIRED, non-optional, protocol-typed: a transfer edit reverses two legs
    /// and re-applies two legs, so it must persist atomically through the ledger
    /// store (one save, rollback on failure). Depend on the seam, not the concrete
    /// `LedgerWriteStore`.
    let ledgerWriting: any LedgerWriting

    init(
        accountRepository: any AccountRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.accountRepository = accountRepository
        self.ledgerWriting = ledgerWriting
    }

    func execute(
        transferPairID: UUID,
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

        // Both legs reversed + re-applied atomically in one save inside the store.
        try await ledgerWriting.performUpdateTransfer(
            transferPairID: transferPairID,
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            amount: amount,
            date: date,
            note: note,
            currencyCode: currencyCode
        )
    }
}
