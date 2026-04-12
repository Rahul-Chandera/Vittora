import Foundation

struct UpdateAccountUseCase: Sendable {
    let accountRepository: any AccountRepository

    init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute(
        id: UUID,
        name: String,
        type: AccountType,
        balance: Decimal,
        currencyCode: String,
        icon: String
    ) async throws {
        // Validate name is not empty
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw VittoraError.validationFailed("Account name cannot be empty")
        }

        // Fetch the existing account
        guard let existingAccount = try await accountRepository.fetchByID(id) else {
            throw VittoraError.notFound("Account not found")
        }

        // Check for duplicate name (excluding current account)
        let allAccounts = try await accountRepository.fetchAll()
        let isDuplicate = allAccounts.contains { account in
            account.id != id &&
            account.name.lowercased() == name.lowercased() &&
            !account.isArchived
        }

        if isDuplicate {
            throw VittoraError.validationFailed("An account with this name already exists")
        }

        // Update the account
        let updatedAccount = AccountEntity(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            balance: balance,
            currencyCode: currencyCode,
            icon: icon,
            isArchived: existingAccount.isArchived,
            createdAt: existingAccount.createdAt,
            updatedAt: .now
        )

        try await accountRepository.update(updatedAccount)
    }
}
