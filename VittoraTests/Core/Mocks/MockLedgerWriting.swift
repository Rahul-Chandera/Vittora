import Foundation
import VittoraCore
@testable import Vittora

/// Lightweight `LedgerWriting` test double for **view-model** tests that only
/// need a write to be reflected in the mock repositories. It is intentionally
/// non-atomic — real one-save atomicity and rollback are covered against a real
/// in-memory container in `LedgerWriteStoreTests` and the use-case suites.
struct MockLedgerWriting: LedgerWriting {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    var debtRepository: (any DebtRepository)? = nil
    var categoryRepository: (any CategoryRepository)? = nil
    var recurringRuleRepository: (any RecurringRuleRepository)? = nil

    func performTransfer(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) async throws {
        throw VittoraError.unknown("MockLedgerWriting.performTransfer not supported")
    }

    func performAdd(_ transaction: TransactionEntity) async throws {
        try await transactionRepository.create(transaction)
        guard let accountID = transaction.accountID,
              var account = try await accountRepository.fetchByID(accountID) else { return }
        account.balance += transaction.signedBalanceEffect
        account.updatedAt = .now
        try await accountRepository.update(account)
    }

    func performUpdate(_ transaction: TransactionEntity) async throws {
        guard transaction.type != .transfer else {
            throw LedgerWriteError.transferNotSupported
        }
        guard let existing = try await transactionRepository.fetchByID(transaction.id) else {
            throw VittoraError.notFound("Transaction not found")
        }
        guard existing.type != .transfer else {
            throw LedgerWriteError.transferNotSupported
        }
        let oldDelta = existing.signedBalanceEffect
        let newDelta = transaction.signedBalanceEffect
        var updated = transaction
        updated.updatedAt = .now
        try await transactionRepository.update(updated)

        if existing.accountID == transaction.accountID {
            if let accountID = transaction.accountID {
                try await adjust(accountID, by: newDelta - oldDelta)
            }
        } else {
            if let oldAccountID = existing.accountID {
                try await adjust(oldAccountID, by: -oldDelta)
            }
            if let newAccountID = transaction.accountID {
                try await adjust(newAccountID, by: newDelta)
            }
        }
    }

    func performUpdateTransfer(
        transferPairID: UUID,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date,
        note: String,
        currencyCode: String
    ) async throws {
        let legs = try await transactionRepository.fetchAll(filter: nil)
            .filter { $0.transferPairID == transferPairID }
        guard !legs.isEmpty else { throw VittoraError.notFound("Transfer not found") }
        guard let debit = legs.first(where: { $0.transferDirection == .debit }),
              let credit = legs.first(where: { $0.transferDirection == .credit }) else {
            throw LedgerWriteError.transferNotSupported
        }
        for leg in legs {
            if let accountID = leg.accountID {
                try await adjust(accountID, by: -leg.signedBalanceEffect)
            }
        }
        var newDebit = debit
        newDebit.amount = amount
        newDebit.date = date
        newDebit.note = note.isEmpty ? nil : note
        newDebit.currencyCode = currencyCode
        newDebit.accountID = sourceAccountID
        newDebit.destinationAccountID = destinationAccountID
        newDebit.updatedAt = .now
        try await transactionRepository.update(newDebit)

        var newCredit = credit
        newCredit.amount = amount
        newCredit.date = date
        newCredit.note = note.isEmpty ? nil : note
        newCredit.currencyCode = currencyCode
        newCredit.accountID = destinationAccountID
        newCredit.destinationAccountID = sourceAccountID
        newCredit.updatedAt = .now
        try await transactionRepository.update(newCredit)

        try await adjust(sourceAccountID, by: -amount)
        try await adjust(destinationAccountID, by: amount)
    }

    func performDelete(transactionID: UUID) async throws {
        guard let tx = try await transactionRepository.fetchByID(transactionID) else {
            throw VittoraError.notFound("Transaction not found")
        }
        var legs = [tx]
        if tx.type == .transfer, let pairID = tx.transferPairID {
            let paired = try await transactionRepository.fetchAll(filter: nil)
                .filter { $0.transferPairID == pairID }
            if !paired.isEmpty { legs = paired }
        }
        for leg in legs {
            if let accountID = leg.accountID,
               try await accountRepository.fetchByID(accountID) != nil {
                try await adjust(accountID, by: -leg.signedBalanceEffect)
            }
            try await transactionRepository.delete(leg.id)
        }
    }

    private func adjust(_ accountID: UUID, by delta: Decimal) async throws {
        guard var account = try await accountRepository.fetchByID(accountID) else {
            throw VittoraError.notFound("Account not found")
        }
        account.balance += delta
        account.updatedAt = .now
        try await accountRepository.update(account)
    }

    func performSettle(debtID: UUID, settlementAmount: Decimal, transaction: TransactionEntity?) async throws {
        guard let debtRepository, var debt = try await debtRepository.fetchByID(debtID) else {
            throw VittoraError.notFound("Debt entry not found")
        }
        debt.settledAmount += settlementAmount
        if debt.settledAmount >= debt.amount {
            debt.isSettled = true
        }
        if let transaction {
            try await performAdd(transaction)
            var ids = debt.linkedTransactionIDs
            ids.append(transaction.id)
            debt.linkedTransactionIDs = ids
        }
        try await debtRepository.update(debt)
    }

    func performDeleteCategory(categoryID: UUID) async throws {
        let filter = TransactionFilter(categoryIDs: [categoryID])
        let linked = try await transactionRepository.fetchAll(filter: filter)
        for var tx in linked {
            tx.categoryID = nil
            tx.updatedAt = .now
            try await transactionRepository.update(tx)
        }
        guard let categoryRepository else {
            throw VittoraError.unknown(String(localized: "Mock category delete not configured"))
        }
        try await categoryRepository.delete(categoryID)
    }

    func performDeleteRecurringRule(ruleID: UUID) async throws {
        let linked = try await transactionRepository.fetchForRecurringRule(ruleID)
        for var tx in linked {
            tx.recurringRuleID = nil
            tx.updatedAt = .now
            try await transactionRepository.update(tx)
        }
        guard let recurringRuleRepository else {
            throw VittoraError.unknown(String(localized: "Mock recurring rule delete not configured"))
        }
        try await recurringRuleRepository.delete(ruleID)
    }
}
