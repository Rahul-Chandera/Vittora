import Foundation

struct UpdateTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    func execute(_ entity: TransactionEntity) async throws {
        // Fetch the existing transaction
        guard let existingTransaction = try await transactionRepository.fetchByID(entity.id) else {
            throw VittoraError.notFound("Transaction not found")
        }

        // Get the account for balance adjustments
        guard let account = try await accountRepository.fetchByID(entity.accountID ?? UUID()) else {
            throw VittoraError.notFound("Account not found")
        }

        // Reverse the old transaction balance effect
        var updatedAccount = account
        updatedAccount.updatedAt = .now

        switch existingTransaction.type {
        case .expense:
            updatedAccount.balance += existingTransaction.amount
        case .income:
            updatedAccount.balance -= existingTransaction.amount
        case .transfer:
            // Transfer balance effects handled by destinationAccountID
            break
        case .adjustment:
            updatedAccount.balance -= existingTransaction.amount
        }

        // Apply the new transaction balance effect
        switch entity.type {
        case .expense:
            updatedAccount.balance -= entity.amount
        case .income:
            updatedAccount.balance += entity.amount
        case .transfer:
            // Transfer balance effects handled by destinationAccountID
            break
        case .adjustment:
            updatedAccount.balance += entity.amount
        }

        // Update the transaction with new updatedAt
        var updatedTransaction = entity
        updatedTransaction.updatedAt = .now

        // Save changes
        try await transactionRepository.update(updatedTransaction)
        try await accountRepository.update(updatedAccount)
    }
}
