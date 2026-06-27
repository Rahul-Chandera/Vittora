import Foundation
import SwiftData

/// Errors surfaced by the ledger write Unit-of-Work.
enum LedgerWriteError: LocalizedError, Sendable {
    /// An operation entry point exists but its body has not been wired yet.
    /// Used only as scaffolding while Epic A tasks fill in the bodies (A4 delete).
    case notImplemented(String)
    /// A referenced account could not be found in the store's context. Thrown
    /// mid-operation so `commit` rolls back and nothing is persisted. This is the
    /// single account-not-found convention for *every* store operation.
    case accountNotFound(UUID)
    /// A `.transfer` was routed through a single-leg path (`performAdd`). Transfers
    /// must go through `performTransfer`, which writes both paired legs atomically.
    case transferNotSupported

    var errorDescription: String? {
        switch self {
        case .notImplemented(let detail):
            String(localized: "Operation not available: \(detail)")
        case .accountNotFound:
            String(localized: "The account for this operation could not be found.")
        case .transferNotSupported:
            String(localized: "Transfers must be made through the transfer flow.")
        }
    }
}

/// Single-context write Unit-of-Work for compound ledger operations.
///
/// Every business operation that mutates more than one record (transfer,
/// add-with-balance, settle, delete-with-reversal) must run through this actor
/// so that *all* of its inserts/updates/deletes share one `ModelContext` and
/// are persisted with exactly one `save()`. If any step throws, the pending
/// changes are rolled back and nothing is written — there is no partially
/// applied state. This is the root fix for the non-atomic, multi-context money
/// writes called out by DATAINTEGRITY-2 / ARCHITECTURE-01.
///
/// `performTransfer` (A3), `performAdd`/`performSettle` (A6) are wired;
/// `performDelete` (A4) is still seeded as a stub.
///
/// Balance math has a single source of truth: `TransactionEntity.signedBalanceEffect`.
/// The store never redefines its own effect mapping.
@ModelActor
actor LedgerWriteStore: LedgerWriting {
    /// Number of successful `save()` calls performed by `commit`. Exposed so
    /// tests can assert that a compound operation persists with exactly one
    /// save and that a rolled-back operation performs none.
    private(set) var saveCount: Int = 0

    /// Runs all mutations for a single business operation in this actor's lone
    /// `ModelContext` and persists them with exactly one `save()`.
    ///
    /// On any thrown error the context is rolled back to its last saved state,
    /// discarding every pending insert/update/delete from `work`, and the error
    /// is rethrown so the caller can surface it. The store is never left with a
    /// half-applied operation.
    func commit(_ work: (ModelContext) throws -> Void) throws {
        do {
            try work(modelContext)
            try modelContext.save()
            saveCount += 1
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Operation entry points
    //
    // Each body routes its full set of mutations through `commit(_:)` so the
    // operation persists atomically.

    /// Move funds between two accounts as a paired, balance-neutral operation
    /// (A3, DATAINTEGRITY-1/2). Inserts two `.transfer` legs sharing one
    /// `transferPairID` — a `.debit` leg on the source and a `.credit` leg on the
    /// destination — and applies both balance adjustments, all in one `save()`.
    /// If anything fails the whole operation rolls back (no ghost leg, no
    /// one-sided balance change).
    func performTransfer(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) throws {
        try commit { context in
            guard let source = try Self.fetchAccount(sourceAccountID, in: context) else {
                throw LedgerWriteError.accountNotFound(sourceAccountID)
            }
            guard let destination = try Self.fetchAccount(destinationAccountID, in: context) else {
                throw LedgerWriteError.accountNotFound(destinationAccountID)
            }

            let pairID = UUID()
            let noteValue = note.isEmpty ? nil : note

            let debitLeg = SDTransaction(
                amount: amount,
                date: date,
                note: noteValue,
                type: .transfer,
                paymentMethod: .bankTransfer,
                currencyCode: currencyCode,
                accountID: sourceAccountID,
                destinationAccountID: destinationAccountID,
                transferPairID: pairID,
                transferDirection: .debit
            )
            let creditLeg = SDTransaction(
                amount: amount,
                date: date,
                note: noteValue,
                type: .transfer,
                paymentMethod: .bankTransfer,
                currencyCode: currencyCode,
                accountID: destinationAccountID,
                destinationAccountID: sourceAccountID,
                transferPairID: pairID,
                transferDirection: .credit
            )

            context.insert(debitLeg)
            context.insert(creditLeg)

            source.balance -= amount
            source.updatedAt = .now
            destination.balance += amount
            destination.updatedAt = .now
        }
    }

    /// Create a transaction and adjust its account balance atomically (A6).
    ///
    /// The transaction is inserted first; the account is then fetched *in this
    /// context* and mutated by `signedBalanceEffect`. If the account id does not
    /// resolve, the throw rolls back the pending insert so nothing is persisted
    /// (DATAINTEGRITY-2). Transfers are rejected — they must use
    /// `performTransfer` so both paired legs are written together.
    func performAdd(_ transaction: TransactionEntity) throws {
        guard transaction.type != .transfer else {
            throw LedgerWriteError.transferNotSupported
        }
        try commit { ctx in
            ctx.insert(Self.makeTransactionModel(from: transaction))
            guard let accountID = transaction.accountID else { return }
            guard let account = try Self.fetchAccount(accountID, in: ctx) else {
                throw LedgerWriteError.accountNotFound(accountID)
            }
            account.balance += transaction.signedBalanceEffect
            account.updatedAt = .now
        }
    }

    /// Apply a debt settlement atomically (A6): bump the debt's settled amount
    /// and, when a linked transaction is supplied, insert it and adjust the
    /// account — all in one save. Any failure (missing debt or account) rolls
    /// back the whole operation so the debt, transaction, and balance never
    /// diverge.
    func performSettle(debtID: UUID, settlementAmount: Decimal, transaction: TransactionEntity?) throws {
        try commit { ctx in
            guard let debt = try Self.fetchDebt(debtID, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Debt entry not found"))
            }
            debt.settledAmount += settlementAmount
            if debt.settledAmount >= debt.amount {
                debt.isSettled = true
            }
            debt.updatedAt = .now

            guard let transaction else { return }
            ctx.insert(Self.makeTransactionModel(from: transaction))
            if let accountID = transaction.accountID {
                guard let account = try Self.fetchAccount(accountID, in: ctx) else {
                    throw LedgerWriteError.accountNotFound(accountID)
                }
                account.balance += transaction.signedBalanceEffect
                account.updatedAt = .now
            }
            debt.linkedTransactionID = transaction.id
        }
    }

    /// Delete a transaction and reverse its balance effects (both legs for a
    /// transfer) atomically.
    /// Body added in A4 (delete/update handling of transfers).
    func performDelete(transactionID: UUID) throws {
        throw LedgerWriteError.notImplemented("performDelete")
    }

    // MARK: - Helpers

    /// Build a fresh `SDTransaction` from a domain entity. Matches
    /// `SwiftDataTransactionRepository.create` so the store and repo agree on
    /// how an entity becomes a row (id preserved, transfer pairing/direction carried).
    private static func makeTransactionModel(from entity: TransactionEntity) -> SDTransaction {
        SDTransaction(
            id: entity.id,
            amount: entity.amount,
            date: entity.date,
            note: entity.note,
            type: entity.type,
            paymentMethod: entity.paymentMethod,
            currencyCode: entity.currencyCode,
            tags: entity.tags,
            categoryID: entity.categoryID,
            accountID: entity.accountID,
            payeeID: entity.payeeID,
            destinationAccountID: entity.destinationAccountID,
            recurringRuleID: entity.recurringRuleID,
            transferPairID: entity.transferPairID,
            transferDirection: entity.transferDirection
        )
    }

    /// Fetch a single account model by id within the given context.
    private static func fetchAccount(_ id: UUID, in context: ModelContext) throws -> SDAccount? {
        var descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchDebt(_ id: UUID, in context: ModelContext) throws -> SDDebt? {
        var descriptor = FetchDescriptor<SDDebt>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
