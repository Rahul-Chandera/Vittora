import Foundation
import SwiftData

/// Errors surfaced by the ledger write Unit-of-Work.
enum LedgerWriteError: LocalizedError, Sendable {
    /// An operation entry point exists but its body has not been wired yet.
    /// Used only as scaffolding while Epic A tasks A3–A6 fill in the bodies.
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let detail):
            String(localized: "Operation not available: \(detail)")
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
/// Operation bodies for the seeded entry points are filled in by the
/// dependent tasks (A3 transfer, A4 delete/update, A6 add/settle).
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
    // Signatures are seeded here so the Unit-of-Work surface is stable for the
    // dependent tasks. Each body routes its full set of mutations through
    // `commit(_:)` so the operation persists atomically.

    /// Move funds between two accounts as a paired, balance-neutral operation.
    /// Body added in A3 (atomic transfer with leg pairing).
    func performTransfer(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) throws {
        throw LedgerWriteError.notImplemented("performTransfer")
    }

    /// Create a transaction and adjust its account balance atomically.
    ///
    /// The transaction is inserted first; the account is then fetched *in this
    /// context* and mutated. If the account id does not resolve, the throw
    /// rolls back the pending insert so nothing is persisted (DATAINTEGRITY-2).
    func performAdd(_ transaction: TransactionEntity) throws {
        try commit { ctx in
            ctx.insert(Self.makeTransactionModel(from: transaction))
            guard let accountID = transaction.accountID else { return }
            guard let account = try Self.fetchAccount(accountID, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Account not found"))
            }
            account.balance += Self.balanceEffect(type: transaction.type, amount: transaction.amount)
            account.updatedAt = .now
        }
    }

    /// Apply a debt settlement atomically: bump the debt's settled amount and,
    /// when a linked transaction is supplied, insert it and adjust the account —
    /// all in one save. Any failure (missing debt or account) rolls back the
    /// whole operation so the debt, transaction, and balance never diverge.
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
                    throw VittoraError.notFound(String(localized: "Account not found"))
                }
                account.balance += Self.balanceEffect(type: transaction.type, amount: transaction.amount)
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

    /// Signed balance delta a transaction applies to its account. Reversing an
    /// effect is the negation of this value. Transfers net out via their paired
    /// leg, so they contribute nothing here. Mirrors `UpdateTransactionUseCase`.
    private static func balanceEffect(type: TransactionType, amount: Decimal) -> Decimal {
        switch type {
        case .expense: -amount
        case .income: amount
        case .transfer: 0
        case .adjustment: amount
        }
    }

    /// Build a fresh `SDTransaction` from a domain entity. Matches
    /// `SwiftDataTransactionRepository.create` so the store and repo agree on
    /// how an entity becomes a row (id preserved, V2 `transferPairID` carried).
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
            transferPairID: entity.transferPairID
        )
    }

    private static func fetchAccount(_ id: UUID, in context: ModelContext) throws -> SDAccount? {
        try context.fetch(FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })).first
    }

    private static func fetchDebt(_ id: UUID, in context: ModelContext) throws -> SDDebt? {
        try context.fetch(FetchDescriptor<SDDebt>(predicate: #Predicate { $0.id == id })).first
    }
}
