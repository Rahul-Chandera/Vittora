import Foundation
import VittoraCore

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

    /// Update a NON-transfer transaction and reconcile balances atomically:
    /// reverse the original leg's effect on its original account and apply the new
    /// effect on the (possibly changed) account — all in one save. Rejects
    /// `.transfer` (edit transfers via `performUpdateTransfer`).
    func performUpdate(_ transaction: TransactionEntity) async throws

    /// Edit BOTH legs of a paired transfer atomically (A4): reverse both old legs'
    /// balance effects, re-point/re-amount both legs, and apply both new effects —
    /// one save. Identified by the shared `transferPairID`. Only A3 direction-
    /// carrying pairs are supported; legacy nil-direction transfers are not editable.
    func performUpdateTransfer(
        transferPairID: UUID,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) async throws

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

    /// Delete a category after nullifying all references to it (A10,
    /// DATAINTEGRITY-6): clears `categoryID` on transactions, budgets, recurring
    /// rule templates, and split group expenses; clears `parentID` on child
    /// categories — then deletes the category row. No balance effects; one save.
    func performDeleteCategory(categoryID: UUID) async throws

    /// Delete a recurring rule after nullifying `recurringRuleID` on every
    /// generated transaction that references it (A10) — then deletes the rule.
    /// No balance effects; one save.
    func performDeleteRecurringRule(ruleID: UUID) async throws
}
