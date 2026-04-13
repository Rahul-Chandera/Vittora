import Foundation

struct SettleDebtUseCase: Sendable {
    let debtRepository: any DebtRepository
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    func execute(
        debtID: UUID,
        settlementAmount: Decimal,
        accountID: UUID?
    ) async throws {
        guard var entry = try await debtRepository.fetchByID(debtID) else {
            throw VittoraError.notFound(String(localized: "Debt entry not found"))
        }
        guard settlementAmount > 0 else {
            throw VittoraError.validationFailed(String(localized: "Settlement amount must be greater than zero"))
        }
        guard settlementAmount <= entry.remainingAmount else {
            throw VittoraError.validationFailed(String(localized: "Settlement amount exceeds remaining balance"))
        }

        entry.settledAmount += settlementAmount
        if entry.settledAmount >= entry.amount {
            entry.isSettled = true
        }

        // Create linked transaction if an account is provided
        if let accountID {
            let transactionType: TransactionType = entry.direction == .lent ? .income : .expense
            let transaction = TransactionEntity(
                amount: settlementAmount,
                date: .now,
                note: entry.note.map { "Settlement: \($0)" } ?? String(localized: "Debt Settlement"),
                type: transactionType,
                paymentMethod: .bankTransfer,
                currencyCode: "USD",
                tags: ["debt-settlement"],
                accountID: accountID
            )
            try await transactionRepository.create(transaction)

            // Update account balance
            if var account = try await accountRepository.fetchByID(accountID) {
                account.balance += transactionType == .income ? settlementAmount : -settlementAmount
                try await accountRepository.update(account)
            }

            entry.linkedTransactionID = transaction.id
        }

        try await debtRepository.update(entry)
    }
}
