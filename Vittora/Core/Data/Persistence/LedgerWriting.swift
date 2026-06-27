import Foundation

/// The atomic write surface for compound ledger operations.
///
/// Every money mutation that touches more than one record (create-with-balance,
/// settle-with-balance, transfer, delete-with-reversal) goes through a single
/// conforming Unit-of-Work so all of its inserts/updates run in one
/// `ModelContext` and persist with exactly one `save()`. Use cases depend on
/// `any LedgerWriting` directly — there is intentionally **no** repository
/// fallback, because a non-atomic fallback re-introduces the multi-context
/// corruption path (DATAINTEGRITY-2 / ARCHITECTURE-01).
///
/// The read-modify-write logic lives inside the conformer: callers pass the
/// fully-formed intent (ids + a prepared `TransactionEntity`) and the store
/// fetches the persisted models by id, mutates them, and saves atomically.
protocol LedgerWriting: Sendable {
    /// Move funds between two accounts as a paired, balance-neutral operation.
    /// (Body lands in A3; the seam is declared here so callers are stable.)
    func performTransfer(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) async throws

    /// Insert a transaction and apply its balance effect to its account in one save.
    func performAdd(_ transaction: TransactionEntity) async throws

    /// Apply a debt settlement: bump the debt's settled amount and, when a
    /// linked transaction is supplied, insert it and adjust the account — all
    /// in one save. Pass `transaction == nil` to settle without a cash leg.
    func performSettle(
        debtID: UUID,
        settlementAmount: Decimal,
        transaction: TransactionEntity?
    ) async throws

    /// Delete a transaction and reverse its balance effects atomically.
    /// (Body lands in A4.)
    func performDelete(transactionID: UUID) async throws
}
