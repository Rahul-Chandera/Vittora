import Foundation

struct BulkOperationsUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    func recategorize(transactionIDs: [UUID], newCategoryID: UUID) async throws {
        for id in transactionIDs {
            guard let transaction = try await transactionRepository.fetchByID(id) else {
                throw VittoraError.notFound("Transaction not found")
            }

            var updatedTransaction = transaction
            updatedTransaction.categoryID = newCategoryID
            updatedTransaction.updatedAt = .now

            try await transactionRepository.update(updatedTransaction)
        }
    }

    func bulkDelete(transactionIDs: [UUID]) async throws {
        // Group transactions by account ID to optimize balance updates
        var transactionsByAccount: [UUID?: [TransactionEntity]] = [:]

        for id in transactionIDs {
            guard let transaction = try await transactionRepository.fetchByID(id) else {
                throw VittoraError.notFound("Transaction not found")
            }

            let accountID = transaction.accountID
            if transactionsByAccount[accountID] == nil {
                transactionsByAccount[accountID] = []
            }
            transactionsByAccount[accountID]?.append(transaction)
        }

        // Update account balances and delete transactions
        for (accountID, transactions) in transactionsByAccount {
            if let accountID = accountID {
                guard let account = try await accountRepository.fetchByID(accountID) else {
                    throw VittoraError.notFound("Account not found")
                }

                var updatedAccount = account
                updatedAccount.updatedAt = .now

                // Reverse balance effects for all transactions
                for transaction in transactions {
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
                }

                try await accountRepository.update(updatedAccount)
            }
        }

        // Delete all transactions
        for id in transactionIDs {
            try await transactionRepository.delete(id)
        }
    }

    func bulkTag(transactionIDs: [UUID], tag: String) async throws {
        for id in transactionIDs {
            guard let transaction = try await transactionRepository.fetchByID(id) else {
                throw VittoraError.notFound("Transaction not found")
            }

            var updatedTransaction = transaction
            updatedTransaction.updatedAt = .now

            // Append tag if not already present
            if !updatedTransaction.tags.contains(tag) {
                updatedTransaction.tags.append(tag)
            }

            try await transactionRepository.update(updatedTransaction)
        }
    }
}
