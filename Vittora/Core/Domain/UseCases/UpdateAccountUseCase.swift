import Foundation

struct UpdateAccountUseCase: Sendable {
    let accountRepository: any AccountRepository

    nonisolated init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute(
        id: UUID,
        name: String,
        type: AccountType,
        balance: Decimal,
        currencyCode: String,
        icon: String,
        statementDayOfMonth: Int? = nil,
        dueDayOfMonth: Int? = nil
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

        // A manual balance edit re-baselines the opening balance by the same
        // delta so reconciliation stays consistent (expected == new balance and
        // no false drift). Legacy accounts (nil opening) stay nil — their
        // implied opening is derived on read, not pinned here (DATAINTEGRITY-12).
        let newOpeningBalance: Decimal? = existingAccount.openingBalance.map {
            $0 + (balance - existingAccount.balance)
        }

        let billingFields = normalizedBillingFields(
            type: type,
            statementDayOfMonth: statementDayOfMonth,
            dueDayOfMonth: dueDayOfMonth
        )

        // Update the account
        let updatedAccount = AccountEntity(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            balance: balance,
            openingBalance: newOpeningBalance,
            currencyCode: currencyCode,
            icon: icon,
            isArchived: existingAccount.isArchived,
            createdAt: existingAccount.createdAt,
            updatedAt: .now,
            statementDayOfMonth: billingFields.statement,
            dueDayOfMonth: billingFields.due
        )

        try await accountRepository.update(updatedAccount)
    }

    private func normalizedBillingFields(
        type: AccountType,
        statementDayOfMonth: Int?,
        dueDayOfMonth: Int?
    ) -> (statement: Int?, due: Int?) {
        guard type == .creditCard else { return (nil, nil) }
        if let statementDayOfMonth, !CreditCardDueDateCalculator.isValidDayOfMonth(statementDayOfMonth) {
            return (nil, dueDayOfMonth)
        }
        if let dueDayOfMonth, !CreditCardDueDateCalculator.isValidDayOfMonth(dueDayOfMonth) {
            return (statementDayOfMonth, nil)
        }
        return (statementDayOfMonth, dueDayOfMonth)
    }
}
