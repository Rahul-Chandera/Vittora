import Foundation
import VittoraCore

struct CreateAccountUseCase: Sendable {
    let accountRepository: any AccountRepository

    nonisolated init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute(
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        currencyCode: String = CurrencyDefaults.code,
        icon: String = "building.columns.fill",
        statementDayOfMonth: Int? = nil,
        dueDayOfMonth: Int? = nil
    ) async throws {
        // Validate name is not empty
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw VittoraError.validationFailed("Account name cannot be empty")
        }

        let billingFields = normalizedBillingFields(
            type: type,
            statementDayOfMonth: statementDayOfMonth,
            dueDayOfMonth: dueDayOfMonth
        )

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
            isArchived: false,
            statementDayOfMonth: billingFields.statement,
            dueDayOfMonth: billingFields.due
        )

        try await accountRepository.create(account)
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
