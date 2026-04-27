import Foundation

struct DeleteAccountUseCase: Sendable {
    let accountRepository: any AccountRepository
    let transactionRepository: any TransactionRepository

    init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }

    func delete(id: UUID) async throws {
        // Fetch the account
        guard try await accountRepository.fetchByID(id) != nil else {
            throw VittoraError.notFound("Account not found")
        }

        // Check if account has any transactions without loading the full history.
        if try await transactionRepository.hasTransactions(forAccountID: id) {
            throw VittoraError.validationFailed("Cannot delete account with transactions. Archive it instead.")
        }

        // Hard delete the account
        try await accountRepository.delete(id)
    }

    func archive(id: UUID) async throws {
        // Fetch the account
        guard var account = try await accountRepository.fetchByID(id) else {
            throw VittoraError.notFound("Account not found")
        }

        // Archive the account (soft delete)
        account.isArchived = true
        account.updatedAt = .now
        try await accountRepository.update(account)
    }
}
