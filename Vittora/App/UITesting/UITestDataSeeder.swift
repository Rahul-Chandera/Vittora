import Foundation
import VittoraCore

@MainActor
final class UITestDataSeeder {
    private let accountRepository: any AccountRepository
    private let categoryRepository: any CategoryRepository
    private let transactionRepository: any TransactionRepository
    private let ledgerWriting: any LedgerWriting

    init(
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        transactionRepository: any TransactionRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.ledgerWriting = ledgerWriting
    }

    /// Rich, realistic dataset for marketing/App Store screenshots
    /// (`--ui-test-seed-demo`): accounts, two months of transactions, budgets,
    /// goals, recurring rules, and a debt — everything the dashboard and list
    /// screens render. Defaults to a USD/US dataset (primary market);
    /// set env `UITEST_DEMO_REGION=IN` for the INR/India variant.
    func seedDemoShowcaseIfNeeded(
        budgetRepository: any BudgetRepository,
        savingsGoalRepository: any SavingsGoalRepository,
        debtRepository: any DebtRepository,
        recurringRuleRepository: any RecurringRuleRepository,
        payeeRepository: any PayeeRepository,
        dataSeeder: any DataSeederProtocol
    ) async throws {
        let existingAccounts = try await accountRepository.fetchAll()
        let existingTransactions = try await transactionRepository.fetchAll(filter: nil)
        guard existingAccounts.isEmpty, existingTransactions.isEmpty else { return }

        // reseed (not seedIfNeeded): the "already seeded" gate is a
        // UserDefaults flag that outlives the fresh in-memory UI-test store,
        // so the IfNeeded variant would skip and leave zero categories.
        try await dataSeeder.reseedDefaultCategories()
        let categories = try await categoryRepository.fetchAll()
        func category(_ name: String) -> UUID? {
            categories.first { $0.name == name }?.id
        }

        // Region-specific dataset. US is the default (primary market for App
        // Store screenshots); pass UITEST_DEMO_REGION=IN for the India set.
        let region = ProcessInfo.processInfo.environment["UITEST_DEMO_REGION"] ?? "US"
        let isIndia = region == "IN"
        let currency = isIndia ? "INR" : "USD"

        // The dashboard formats amounts with the user's selected currency;
        // align it with the seeded data so symbols match.
        UserDefaults.standard.set(currency, forKey: AppUserDefaults.StandardKey.currencyCode)

        let bank = AccountEntity(
            name: isIndia ? "HDFC Salary" : "Chase Checking",
            type: .bank, balance: isIndia ? 30_000 : 4_200,
            currencyCode: currency, icon: "building.columns.fill"
        )
        let cash = AccountEntity(
            name: isIndia ? "Cash Wallet" : "Cash",
            type: .cash, balance: isIndia ? 6_000 : 250,
            currencyCode: currency, icon: "banknote.fill"
        )
        let card = AccountEntity(
            name: isIndia ? "ICICI Credit Card" : "Amex Credit Card",
            type: .creditCard, balance: 0,
            currencyCode: currency, icon: "creditcard.fill"
        )
        for account in [bank, cash, card] {
            try await accountRepository.create(account)
        }

        let food = PayeeEntity(name: isIndia ? "Swiggy" : "DoorDash")
        let grocer = PayeeEntity(name: isIndia ? "BigBasket" : "Whole Foods")
        let friend = PayeeEntity(name: isIndia ? "Arjun" : "Alex Carter", type: .person)
        for payee in [food, grocer, friend] {
            try await payeeRepository.create(payee)
        }

        let addTransaction = AddTransactionUseCase(
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            ledgerWriting: ledgerWriting
        )
        // Dates anchor to calendar months (not "N days ago") so the dashboard's
        // "This Month" card always shows income + spending, and the previous
        // month exists for comparison arrows and trend charts. Days that
        // haven't happened yet this month clamp to now.
        let calendar = Calendar.current
        func monthDay(_ monthOffset: Int, _ day: Int) -> Date {
            let start = calendar.date(
                from: calendar.dateComponents([.year, .month], from: .now)
            ) ?? .now
            let month = calendar.date(byAdding: .month, value: monthOffset, to: start) ?? start
            let date = calendar.date(byAdding: .day, value: day - 1, to: month) ?? month
            return min(date, .now)
        }

        typealias Entry = (Decimal, TransactionType, Int, Int, String, AccountEntity, PayeeEntity?, String, PaymentMethod)
        let entries: [Entry]
        if isIndia {
            entries = [
                // Previous month — history for comparisons and charts.
                (85_000, .income, -1, 1, "Salary", bank, nil, "Monthly Salary", .bankTransfer),
                (22_000, .expense, -1, 2, "Rent", bank, nil, "Monthly Rent", .bankTransfer),
                (2_180, .expense, -1, 5, "Groceries", bank, grocer, "Weekly Groceries", .upi),
                (1_390, .expense, -1, 9, "Utilities", bank, nil, "Electricity Bill", .upi),
                (760, .expense, -1, 11, "Dining", card, food, "Dinner Order", .creditCard),
                (2_420, .expense, -1, 14, "Groceries", bank, grocer, "Groceries Top-up", .upi),
                (649, .expense, -1, 15, "Subscriptions", card, nil, "Netflix", .creditCard),
                (980, .expense, -1, 19, "Transport", bank, nil, "Fuel", .debitCard),
                (1_760, .expense, -1, 24, "Groceries", bank, grocer, "Monthly Staples", .upi),
                (540, .expense, -1, 27, "Dining", card, food, "Lunch Order", .upi),
                // Current month.
                (85_000, .income, 0, 1, "Salary", bank, nil, "Monthly Salary", .bankTransfer),
                (22_000, .expense, 0, 2, "Rent", bank, nil, "Monthly Rent", .bankTransfer),
                (2_340, .expense, 0, 3, "Groceries", bank, grocer, "Weekly Groceries", .upi),
                (1_450, .expense, 0, 5, "Utilities", bank, nil, "Electricity Bill", .upi),
                (640, .expense, 0, 6, "Dining", card, food, "Dinner Order", .creditCard),
                (3_499, .expense, 0, 7, "Shopping", card, nil, "Running Shoes", .creditCard),
                (1_890, .expense, 0, 8, "Groceries", bank, grocer, "Groceries Top-up", .upi),
                (350, .expense, 0, 9, "Transport", cash, nil, "Cab to Office", .cash),
                (649, .expense, 0, 10, "Subscriptions", card, nil, "Netflix", .creditCard),
                (890, .expense, 0, 11, "Dining", card, food, "Weekend Brunch", .creditCard),
                (800, .expense, 0, 11, "Entertainment", card, nil, "Movie Night", .upi),
                (1_200, .expense, 0, 12, "Transport", bank, nil, "Fuel", .debitCard),
                (2_610, .expense, 0, 13, "Groceries", bank, grocer, "Monthly Staples", .upi),
                (560, .expense, 0, 13, "Health", cash, nil, "Pharmacy", .cash),
                (420, .expense, 0, 14, "Dining", card, food, "Lunch Order", .upi),
            ]
        } else {
            entries = [
                // Previous month — history for comparisons and charts.
                (6_400, .income, -1, 1, "Salary", bank, nil, "Monthly Salary", .bankTransfer),
                (1_850, .expense, -1, 2, "Rent", bank, nil, "Monthly Rent", .bankTransfer),
                (128.40, .expense, -1, 5, "Groceries", card, grocer, "Weekly Groceries", .creditCard),
                (96.20, .expense, -1, 9, "Utilities", bank, nil, "Electric Bill", .bankTransfer),
                (42.75, .expense, -1, 11, "Dining", card, food, "Dinner Delivery", .creditCard),
                (142.10, .expense, -1, 14, "Groceries", card, grocer, "Groceries Restock", .creditCard),
                (15.49, .expense, -1, 15, "Subscriptions", card, nil, "Netflix", .creditCard),
                (48.30, .expense, -1, 19, "Transport", card, nil, "Gas", .creditCard),
                (89.65, .expense, -1, 24, "Groceries", card, grocer, "Monthly Staples", .creditCard),
                (28.90, .expense, -1, 27, "Dining", card, food, "Lunch Order", .creditCard),
                // Current month.
                (6_400, .income, 0, 1, "Salary", bank, nil, "Monthly Salary", .bankTransfer),
                (1_850, .expense, 0, 2, "Rent", bank, nil, "Monthly Rent", .bankTransfer),
                (132.80, .expense, 0, 3, "Groceries", card, grocer, "Weekly Groceries", .creditCard),
                (101.50, .expense, 0, 5, "Utilities", bank, nil, "Electric Bill", .bankTransfer),
                (36.40, .expense, 0, 6, "Dining", card, food, "Dinner Delivery", .creditCard),
                (189.99, .expense, 0, 7, "Shopping", card, nil, "Running Shoes", .creditCard),
                (118.25, .expense, 0, 8, "Groceries", card, grocer, "Groceries Restock", .creditCard),
                (24.50, .expense, 0, 9, "Transport", card, nil, "Uber to Airport", .creditCard),
                (15.49, .expense, 0, 10, "Subscriptions", card, nil, "Netflix", .creditCard),
                (54.20, .expense, 0, 11, "Dining", card, food, "Weekend Brunch", .creditCard),
                (32.00, .expense, 0, 11, "Entertainment", card, nil, "Movie Night", .debitCard),
                (52.75, .expense, 0, 12, "Transport", card, nil, "Gas", .creditCard),
                (96.40, .expense, 0, 13, "Groceries", card, grocer, "Monthly Staples", .creditCard),
                (27.35, .expense, 0, 13, "Health", cash, nil, "Pharmacy", .cash),
                (18.60, .expense, 0, 14, "Dining", card, food, "Lunch Order", .creditCard),
            ]
        }
        for entry in entries {
            _ = try await addTransaction.execute(
                amount: entry.0,
                type: entry.1,
                date: monthDay(entry.2, entry.3),
                categoryID: category(entry.4),
                accountID: entry.5.id,
                payeeID: entry.6?.id,
                note: entry.7,
                tags: [],
                paymentMethod: entry.8,
                currencyCode: currency
            )
        }

        let monthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        ) ?? .now
        // Cover every major spending category: the dashboard's overall budget
        // bar compares ALL monthly spending against the SUM of budgets, so an
        // unbudgeted rent-sized expense pins it to a red 100%.
        let budgets: [(String, Decimal)] = isIndia
            ? [
                ("Rent", 22_000), ("Groceries", 10_000), ("Shopping", 6_000),
                ("Dining", 4_000), ("Transport", 3_000), ("Utilities", 2_500),
                ("Entertainment", 2_000), ("Health", 2_000), ("Subscriptions", 1_500)
              ]
            : [
                ("Rent", 1_850), ("Groceries", 650), ("Shopping", 350),
                ("Dining", 250), ("Transport", 250), ("Utilities", 150),
                ("Entertainment", 100), ("Health", 100), ("Subscriptions", 50)
              ]
        for budget in budgets {
            try await budgetRepository.create(BudgetEntity(
                amount: budget.1, period: .monthly,
                startDate: monthStart, categoryID: category(budget.0)
            ))
        }

        try await savingsGoalRepository.create(SavingsGoalEntity(
            name: "Emergency Fund", category: .emergency,
            targetAmount: isIndia ? 150_000 : 15_000,
            currentAmount: isIndia ? 95_000 : 9_500,
            colorHex: "#34C759"
        ))
        try await savingsGoalRepository.create(SavingsGoalEntity(
            name: isIndia ? "Goa Trip" : "Hawaii Trip", category: .travel,
            targetAmount: isIndia ? 40_000 : 5_000,
            currentAmount: isIndia ? 12_500 : 1_800,
            colorHex: "#007AFF"
        ))

        try await debtRepository.create(DebtEntry(
            payeeID: friend.id,
            amount: isIndia ? 5_000 : 250,
            settledAmount: isIndia ? 2_000 : 100,
            direction: .lent, note: "Concert tickets"
        ))

        func daysAhead(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        }
        let recurringRules: [(Decimal, String, String, Int)] = isIndia
            ? [(85_000, "Monthly Salary", "Salary", 6), (22_000, "Rent", "Rent", 7), (649, "Netflix", "Subscriptions", 22)]
            : [(6_400, "Monthly Salary", "Salary", 6), (1_850, "Rent", "Rent", 7), (15.49, "Netflix", "Subscriptions", 22)]
        for rule in recurringRules {
            try await recurringRuleRepository.create(RecurringRuleEntity(
                frequency: .monthly,
                nextDate: daysAhead(rule.3),
                templateAmount: rule.0,
                templateNote: rule.1,
                templateCategoryID: category(rule.2),
                templateAccountID: bank.id
            ))
        }
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
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            ledgerWriting: ledgerWriting
        )

        _ = try await addTransactionUseCase.execute(
            amount: 12.50,
            type: .expense,
            date: Date.now,
            categoryID: groceriesCategory.id,
            accountID: checkingAccount.id,
            payeeID: nil,
            note: "Coffee Run",
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
            note: "Monthly Salary",
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
