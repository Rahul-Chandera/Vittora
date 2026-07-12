import Foundation
import VittoraCore

struct SettleDebtUseCase: Sendable {
    let debtRepository: any DebtRepository
    let accountRepository: any AccountRepository
    /// Required atomic write surface — no repository fallback. The debt bump,
    /// the linked transaction insert, and the balance change must land in one
    /// save so they never diverge (DATAINTEGRITY-2).
    let ledgerWriting: any LedgerWriting

    func execute(
        debtID: UUID,
        settlementAmount: Decimal,
        accountID: UUID?
    ) async throws {
        guard let entry = try await debtRepository.fetchByID(debtID) else {
            throw VittoraError.notFound(String(localized: "Debt entry not found"))
        }
        guard settlementAmount > 0 else {
            throw VittoraError.validationFailed(String(localized: "Settlement amount must be greater than zero"))
        }
        guard settlementAmount <= entry.remainingAmount else {
            throw VittoraError.validationFailed(String(localized: "Settlement amount exceeds remaining balance"))
        }

        // Prepare the linked cash leg when an account is provided. The store
        // performs the read-modify-write (debt + transaction + balance).
        var transaction: TransactionEntity?
        if let accountID {
            let account = try await accountRepository.fetchByID(accountID)
            let transactionType: TransactionType = entry.direction == .lent ? .income : .expense
            transaction = TransactionEntity(
                amount: settlementAmount,
                date: .now,
                note: entry.note.map { "Settlement: \($0)" } ?? String(localized: "Debt Settlement"),
                type: transactionType,
                paymentMethod: .bankTransfer,
                currencyCode: account?.currencyCode ?? CurrencyDefaults.code,
                tags: ["debt-settlement"],
                accountID: accountID
            )
        }

        try await ledgerWriting.performSettle(
            debtID: debtID,
            settlementAmount: settlementAmount,
            transaction: transaction
        )
    }
}
