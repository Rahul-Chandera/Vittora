import Foundation

struct DeleteTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    func execute(id: UUID) async throws {
        // Fetch the transaction to be deleted
        guard let transaction = try await transactionRepository.fetchByID(id) else {
            throw VittoraError.notFound("Transaction not found")
        }

        // Reverse the balance effect on the account
        if let accountID = transaction.accountID {
            guard let account = try await accountRepository.fetchByID(accountID) else {
                throw VittoraError.notFound("Account not found")
            }

            var updatedAccount = account
            updatedAccount.updatedAt = .now

            switch transaction.type {
            case .expense:
                updatedAccount.balance += transaction.amount
            case .income:
                updatedAccount.balance -= transaction.amount
            case .transfer:
                // Transfer balance effects handled by destinationAccountID
                break
            case .adjustment:
                updatedAccount.balance -= transaction.amount
            }

            try await accountRepository.update(updatedAccount)
        }

        // Delete the transaction
        try await transactionRepository.delete(id)
    }

    func executeBulk(ids: [UUID]) async throws {
        for id in ids {
            try await execute(id: id)
        }
    }
}
