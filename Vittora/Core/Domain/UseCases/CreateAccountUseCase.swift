import Foundation

struct CreateAccountUseCase: Sendable {
    let accountRepository: any AccountRepository

    init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute(
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        currencyCode: String = CurrencyDefaults.code,
        icon: String = "building.columns.fill"
    ) async throws {
        // Validate name is not empty
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw VittoraError.validationFailed("Account name cannot be empty")
        }

        // Check for duplicate name
        let existingAccounts = try await accountRepository.fetchAll()
        let isDuplicate = existingAccounts.contains { account in
            account.name.lowercased() == name.lowercased() && !account.isArchived
        }

        if isDuplicate {
            throw VittoraError.validationFailed("An account with this name already exists")
        }

        // Create the account. A brand-new account has no transactions yet, so
        // its opening balance equals its starting balance — this seeds the
        // reconciliation baseline (DATAINTEGRITY-12).
        let account = AccountEntity(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            balance: balance,
            openingBalance: balance,
            currencyCode: currencyCode,
            icon: icon,
            isArchived: false
        )

        try await accountRepository.create(account)
    }
}
