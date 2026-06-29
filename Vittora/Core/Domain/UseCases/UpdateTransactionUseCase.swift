import Foundation
import VittoraCore

struct UpdateTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    /// REQUIRED, non-optional: a transaction edit reverses one balance effect and
    /// applies another, so it must persist atomically through the ledger store
    /// (one save, rollback on failure). There is no non-atomic repository fallback
    /// (DATAINTEGRITY-3, A4).
    let ledgerWriting: any LedgerWriting

    nonisolated init(
        transactionRepository: any TransactionRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.transactionRepository = transactionRepository
        self.ledgerWriting = ledgerWriting
    }

    func execute(_ entity: TransactionEntity) async throws {
        // Fetch the existing transaction so we can both guard transfers and let
        // the store reverse its *original* effect against its *original* account.
        guard let existingTransaction = try await transactionRepository.fetchByID(entity.id) else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }

        // GUARD (Option B, A4): the generic edit path must NOT touch transfers. A
        // transfer is two paired legs; editing one through this single-leg form
        // would drop its `transferPairID`/direction and desync balances. Transfer
        // edits go through the dedicated transfer flow (`performUpdateTransfer`).
        guard existingTransaction.type != .transfer, entity.type != .transfer else {
            throw VittoraError.validationFailed(
                String(localized: "Transfers can't be edited here. Edit them from the transfer screen.")
            )
        }

        // Atomic reverse-old / apply-new (handles same-account netting and
        // account changes) inside one ledger-store save.
        try await ledgerWriting.performUpdate(entity)
    }
}
