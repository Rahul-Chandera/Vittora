import Foundation
import SwiftData
import VittoraCore

/// Errors surfaced by the ledger write Unit-of-Work.
enum LedgerWriteError: LocalizedError, Sendable {
    /// A referenced account could not be found in the store's context. Thrown
    /// mid-operation so `commit` rolls back and nothing is persisted. This is the
    /// single account-not-found convention for *every* store operation.
    case accountNotFound(UUID)
    /// A `.transfer` was routed through a single-leg path (`performAdd`). Transfers
    /// must go through `performTransfer`, which writes both paired legs atomically.
    case transferNotSupported

    var errorDescription: String? {
        switch self {
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
/// `performTransfer` (A3), `performAdd`/`performSettle` (A6), and
/// `performUpdate`/`performUpdateTransfer`/`performDelete` (A4) are all wired.
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
    func commit(_ work: @Sendable (ModelContext) throws -> Void) throws {
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
            Self.appendLinkedTransaction(debt, transactionID: transaction.id)
        }
    }

    /// Promote a legacy single link into the array, then append (A11).
    nonisolated private static func appendLinkedTransaction(_ debt: SDDebt, transactionID: UUID) {
        var ids = debt.linkedTransactionIDs
        if ids.isEmpty, let legacy = debt.linkedTransactionID {
            ids = [legacy]
            debt.linkedTransactionID = nil
        }
        ids.append(transactionID)
        debt.linkedTransactionIDs = ids
    }

    /// Update a non-transfer transaction and reconcile balances atomically (A4).
    ///
    /// Reverses the *original* leg's effect on its *original* account and applies
    /// the new effect on the (possibly changed) account, then writes the row — all
    /// in one save. When the account is unchanged the two effects are netted in a
    /// single adjustment. Transfers are rejected here (defense in depth alongside
    /// the generic-path guard in `UpdateTransactionUseCase`); they must use
    /// `performUpdateTransfer` so both paired legs stay consistent.
    func performUpdate(_ transaction: TransactionEntity) throws {
        guard transaction.type != .transfer else {
            throw LedgerWriteError.transferNotSupported
        }
        try commit { ctx in
            guard let model = try Self.fetchTransaction(transaction.id, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Transaction not found"))
            }
            // A transfer leg may only be edited through the paired-transfer path.
            guard model.type != .transfer else {
                throw LedgerWriteError.transferNotSupported
            }

            let oldDelta = TransactionMapper.toEntity(model).signedBalanceEffect
            let oldAccountID = model.accountID
            let newAccountID = transaction.accountID

            TransactionMapper.updateModel(model, from: transaction)
            let newDelta = transaction.signedBalanceEffect

            if oldAccountID == newAccountID {
                guard let accountID = newAccountID else { return }
                try Self.adjustAccount(accountID, by: newDelta - oldDelta, in: ctx)
            } else {
                if let oldAccountID {
                    try Self.adjustAccount(oldAccountID, by: -oldDelta, in: ctx)
                }
                if let newAccountID {
                    try Self.adjustAccount(newAccountID, by: newDelta, in: ctx)
                }
            }
        }
    }

    /// Edit both legs of a paired transfer atomically (A4). Reverses both old
    /// legs' effects on their accounts, re-points/re-amounts the `.debit` and
    /// `.credit` legs to the new source/destination, and applies the new effects —
    /// all in one save. Only A3 direction-carrying pairs are editable; a pair that
    /// is missing a `.debit`/`.credit` leg (legacy nil-direction) is rejected.
    func performUpdateTransfer(
        transferPairID: UUID,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) throws {
        try commit { ctx in
            let legs = try Self.fetchTransferLegs(pairID: transferPairID, in: ctx)
            guard !legs.isEmpty else {
                throw VittoraError.notFound(String(localized: "Transfer not found"))
            }
            guard let debitLeg = legs.first(where: { $0.transferDirection == .debit }),
                  let creditLeg = legs.first(where: { $0.transferDirection == .credit }) else {
                // Legacy nil-direction pair — not balance-derivable, so not editable.
                throw LedgerWriteError.transferNotSupported
            }

            // Reverse the old effects first (using each leg's own current values),
            // fetching accounts within this context so an unchanged account nets.
            for leg in legs {
                if let accountID = leg.accountID {
                    let effect = TransactionMapper.toEntity(leg).signedBalanceEffect
                    try Self.adjustAccount(accountID, by: -effect, in: ctx)
                }
            }

            guard let newSource = try Self.fetchAccount(sourceAccountID, in: ctx) else {
                throw LedgerWriteError.accountNotFound(sourceAccountID)
            }
            guard let newDestination = try Self.fetchAccount(destinationAccountID, in: ctx) else {
                throw LedgerWriteError.accountNotFound(destinationAccountID)
            }

            let noteValue = note.isEmpty ? nil : note
            for leg in [debitLeg, creditLeg] {
                leg.amount = amount
                leg.date = date
                leg.note = noteValue
                leg.currencyCode = currencyCode
                leg.updatedAt = .now
            }
            debitLeg.accountID = sourceAccountID
            debitLeg.destinationAccountID = destinationAccountID
            creditLeg.accountID = destinationAccountID
            creditLeg.destinationAccountID = sourceAccountID

            newSource.balance -= amount
            newSource.updatedAt = .now
            newDestination.balance += amount
            newDestination.updatedAt = .now
        }
    }

    /// Delete a transaction and reverse its balance effect atomically (A4).
    ///
    /// For an A3 transfer (a leg carrying a `transferPairID`), BOTH paired legs
    /// are reversed — each leg's `signedBalanceEffect` is removed from its own
    /// account — and both rows are deleted in one save. For a non-transfer row the
    /// single effect is reversed and the row deleted. **Legacy nil-`transferPairID`
    /// transfers (best-effort):** their leg has `signedBalanceEffect == 0` (no
    /// direction), so no balance is changed and only the selected row is removed —
    /// matching the historical behavior; the symmetric partner row (unlinkable
    /// without a pair id) is left untouched. An account that can no longer be
    /// resolved is skipped (nothing to reverse) rather than failing the delete.
    func performDelete(transactionID: UUID) throws {
        try commit { ctx in
            guard let model = try Self.fetchTransaction(transactionID, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Transaction not found"))
            }

            // Legacy nil-pairID transfer = best-effort: legs stays [model], so we
            // delete only the tapped leg with no balance reversal (its
            // signedBalanceEffect is 0 and the symmetric partner is unlinkable).
            var legs: [SDTransaction] = [model]
            if model.type == .transfer, let pairID = model.transferPairID {
                let paired = try Self.fetchTransferLegs(pairID: pairID, in: ctx)
                if !paired.isEmpty {
                    legs = paired
                }
            }

            for leg in legs {
                if let accountID = leg.accountID,
                   let account = try Self.fetchAccount(accountID, in: ctx) {
                    account.balance -= TransactionMapper.toEntity(leg).signedBalanceEffect
                    account.updatedAt = .now
                }
                ctx.delete(leg)
            }
        }
    }

    /// Nullify every reference to a category and delete it atomically (A10).
    func performDeleteCategory(categoryID: UUID) throws {
        try commit { ctx in
            guard let category = try Self.fetchCategory(categoryID, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Category not found"))
            }
            guard !category.isDefault else {
                throw VittoraError.validationFailed(
                    String(localized: "Cannot delete a default category.")
                )
            }

            for tx in try Self.fetchTransactions(categoryID: categoryID, in: ctx) {
                tx.categoryID = nil
                tx.updatedAt = .now
            }
            for budget in try Self.fetchBudgets(categoryID: categoryID, in: ctx) {
                budget.categoryID = nil
                budget.updatedAt = .now
            }
            for rule in try Self.fetchRecurringRules(templateCategoryID: categoryID, in: ctx) {
                rule.templateCategoryID = nil
                rule.updatedAt = .now
            }
            for expense in try Self.fetchGroupExpenses(categoryID: categoryID, in: ctx) {
                expense.categoryID = nil
                expense.updatedAt = .now
            }
            for child in try Self.fetchChildCategories(parentID: categoryID, in: ctx) {
                child.parentID = nil
                child.updatedAt = .now
            }

            ctx.delete(category)
        }
    }

    /// Nullify `recurringRuleID` on generated transactions and delete the rule (A10).
    func performDeleteRecurringRule(ruleID: UUID) throws {
        try commit { ctx in
            guard let rule = try Self.fetchRecurringRule(ruleID, in: ctx) else {
                throw VittoraError.notFound(String(localized: "Recurring rule not found"))
            }

            for tx in try Self.fetchTransactions(recurringRuleID: ruleID, in: ctx) {
                tx.recurringRuleID = nil
                tx.updatedAt = .now
            }

            ctx.delete(rule)
        }
    }

    // MARK: - Helpers

    /// Apply a signed delta to an account's balance within the given context,
    /// throwing `accountNotFound` (so `commit` rolls back) if it cannot be resolved.
    nonisolated private static func adjustAccount(_ id: UUID, by delta: Decimal, in context: ModelContext) throws {
        guard let account = try fetchAccount(id, in: context) else {
            throw LedgerWriteError.accountNotFound(id)
        }
        account.balance += delta
        account.updatedAt = .now
    }

    /// Fetch a single transaction model by id within the given context.
    nonisolated private static func fetchTransaction(_ id: UUID, in context: ModelContext) throws -> SDTransaction? {
        var descriptor = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Fetch all transfer legs sharing a `transferPairID` within the given context.
    nonisolated private static func fetchTransferLegs(pairID: UUID, in context: ModelContext) throws -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.transferPairID == pairID }
        )
        return try context.fetch(descriptor)
    }

    /// Build a fresh `SDTransaction` from a domain entity. Matches
    /// `SwiftDataTransactionRepository.create` so the store and repo agree on
    /// how an entity becomes a row (id preserved, transfer pairing/direction carried).
    nonisolated private static func makeTransactionModel(from entity: TransactionEntity) -> SDTransaction {
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
    nonisolated private static func fetchAccount(_ id: UUID, in context: ModelContext) throws -> SDAccount? {
        var descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func fetchDebt(_ id: UUID, in context: ModelContext) throws -> SDDebt? {
        var descriptor = FetchDescriptor<SDDebt>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func fetchCategory(_ id: UUID, in context: ModelContext) throws -> SDCategory? {
        var descriptor = FetchDescriptor<SDCategory>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func fetchRecurringRule(_ id: UUID, in context: ModelContext) throws -> SDRecurringRule? {
        var descriptor = FetchDescriptor<SDRecurringRule>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func fetchTransactions(categoryID: UUID, in context: ModelContext) throws -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.categoryID == categoryID }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchTransactions(recurringRuleID: UUID, in context: ModelContext) throws -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.recurringRuleID == recurringRuleID }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchBudgets(categoryID: UUID, in context: ModelContext) throws -> [SDBudget] {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { $0.categoryID == categoryID }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchRecurringRules(templateCategoryID: UUID, in context: ModelContext) throws -> [SDRecurringRule] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.templateCategoryID == templateCategoryID }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchGroupExpenses(categoryID: UUID, in context: ModelContext) throws -> [SDGroupExpense] {
        let descriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.categoryID == categoryID }
        )
        return try context.fetch(descriptor)
    }

    nonisolated private static func fetchChildCategories(parentID: UUID, in context: ModelContext) throws -> [SDCategory] {
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.parentID == parentID }
        )
        return try context.fetch(descriptor)
    }
}
