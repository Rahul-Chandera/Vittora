import Foundation

@MainActor
final class UITestDataSeeder {
    private let accountRepository: any AccountRepository
    private let categoryRepository: any CategoryRepository
    private let transactionRepository: any TransactionRepository

    init(
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
    }

    func seedTransactionScenarioIfNeeded() async throws {
        let existingAccounts = try await accountRepository.fetchAll()
        let existingTransactions = try await transactionRepository.fetchAll(filter: nil)
        guard existingAccounts.isEmpty, existingTransactions.isEmpty else {
            return
        }

        let checkingAccount = AccountEntity(
            id: fixedUUID("A4E10B49-A24C-4C32-A4BE-53C6D9951D01"),
            name: String(localized: "UI Test Checking"),
            type: .bank,
            balance: 1_500,
            currencyCode: "USD",
            icon: "building.columns.fill"
        )
        try await accountRepository.create(checkingAccount)

        let groceriesCategory = CategoryEntity(
            id: fixedUUID("1B89B0F8-B268-4D42-A9C2-D78773630A11"),
            name: String(localized: "Groceries"),
            icon: "cart.fill",
            colorHex: "#34C759",
            type: .expense,
            isDefault: true,
            sortOrder: 0
        )
        let salaryCategory = CategoryEntity(
            id: fixedUUID("B2C52D33-0DD9-4F69-9560-C0A4B087E722"),
            name: String(localized: "Salary"),
            icon: "banknote.fill",
            colorHex: "#007AFF",
            type: .income,
            isDefault: true,
            sortOrder: 0
        )

        try await categoryRepository.create(groceriesCategory)
        try await categoryRepository.create(salaryCategory)

        let addTransactionUseCase = AddTransactionUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository
        )

        _ = try await addTransactionUseCase.execute(
            amount: 12.50,
            type: .expense,
            date: Date.now,
            categoryID: groceriesCategory.id,
            accountID: checkingAccount.id,
            payeeID: nil,
            note: String(localized: "Coffee Run"),
            tags: ["coffee"],
            paymentMethod: .debitCard,
            currencyCode: "USD"
        )

        _ = try await addTransactionUseCase.execute(
            amount: 3_200,
            type: .income,
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date.now) ?? Date.now,
            categoryID: salaryCategory.id,
            accountID: checkingAccount.id,
            payeeID: nil,
            note: String(localized: "Monthly Salary"),
            tags: ["income"],
            paymentMethod: .bankTransfer,
            currencyCode: "USD"
        )
    }

    func seedTransferScenarioIfNeeded() async throws {
        let existingAccounts = try await accountRepository.fetchAll()
        let existingTransactions = try await transactionRepository.fetchAll(filter: nil)
        guard existingAccounts.isEmpty, existingTransactions.isEmpty else {
            return
        }

        let checkingAccount = AccountEntity(
            id: fixedUUID("3F2C22FE-BAA8-46F9-A31C-1E6E66281C41"),
            name: String(localized: "UI Test Checking"),
            type: .bank,
            balance: 1_500,
            currencyCode: "USD",
            icon: "building.columns.fill"
        )
        let savingsAccount = AccountEntity(
            id: fixedUUID("2BDAE8B4-4918-4F0E-B03C-72D8F428E553"),
            name: String(localized: "UI Test Savings"),
            type: .bank,
            balance: 500,
            currencyCode: "USD",
            icon: "banknote.fill"
        )

        try await accountRepository.create(checkingAccount)
        try await accountRepository.create(savingsAccount)
    }

    private func fixedUUID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue) ?? UUID()
    }
}
