import Foundation
@testable import Vittora

/// Lightweight `LedgerWriting` test double for **view-model** tests that only
/// need a write to be reflected in the mock repositories. It is intentionally
/// non-atomic — real one-save atomicity and rollback are covered against a real
/// in-memory container in `LedgerWriteStoreTests` and the use-case suites.
struct MockLedgerWriting: LedgerWriting {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    var debtRepository: (any DebtRepository)? = nil

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
            debt.linkedTransactionID = transaction.id
        }
        try await debtRepository.update(debt)
    }

    func performDelete(transactionID: UUID) async throws {
        throw VittoraError.unknown("MockLedgerWriting.performDelete not supported")
    }
}
