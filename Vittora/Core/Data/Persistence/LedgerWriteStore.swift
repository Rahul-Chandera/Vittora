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
actor LedgerWriteStore {
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
    /// Body added in A6 (atomic add/settle writes).
    func performAdd(_ transaction: TransactionEntity) throws {
        throw LedgerWriteError.notImplemented("performAdd")
    }

    /// Record a debt settlement: create a transaction, adjust the account
    /// balance, and update the debt in one save.
    /// Body added in A6 (atomic add/settle writes).
    func performSettle(debtID: UUID, transaction: TransactionEntity) throws {
        throw LedgerWriteError.notImplemented("performSettle")
    }

    /// Delete a transaction and reverse its balance effects (both legs for a
    /// transfer) atomically.
    /// Body added in A4 (delete/update handling of transfers).
    func performDelete(transactionID: UUID) throws {
        throw LedgerWriteError.notImplemented("performDelete")
    }
}
