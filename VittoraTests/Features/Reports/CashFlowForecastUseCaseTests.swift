import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Cash Flow Forecast Use Case Tests")
struct CashFlowForecastUseCaseTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }

    private var today: Date { date(2026, 7, 19) }

    @Test("wires repository balances, discretionary window, and recurring dates into forecast math")
    @MainActor
    func wiresRepositoryDataIntoForecast() async throws {
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()

        let checking = AccountEntity(
            name: "Checking",
            type: .bank,
            balance: 4_200,
            currencyCode: "USD"
        )
        let cash = AccountEntity(
            name: "Cash",
            type: .cash,
            balance: 250,
            currencyCode: "USD"
        )
        try await accounts.create(checking)
        try await accounts.create(cash)

        let salary = CategoryEntity(name: "Salary", icon: "banknote", type: .income)
        let rent = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        let groceries = CategoryEntity(name: "Groceries", icon: "cart", type: .expense)
        try await categories.create(salary)
        try await categories.create(rent)
        try await categories.create(groceries)

        // 10 days of history: one discretionary $50 expense each day → avg $50/day
        for offset in 1...10 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            await transactions.seed(TransactionEntity(
                amount: 50,
                date: day,
                type: .expense,
                categoryID: groceries.id,
                accountID: checking.id
            ))
        }
        // Recurring-linked expense must NOT count toward discretionary.
        await transactions.seed(TransactionEntity(
            amount: 1_850,
            date: date(2026, 7, 10),
            type: .expense,
            categoryID: rent.id,
            accountID: checking.id,
            recurringRuleID: UUID()
        ))

        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 7, 25), // day +6
            templateAmount: 6_400,
            templateNote: "Monthly Salary",
            templateCategoryID: salary.id,
            templateAccountID: checking.id
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 7, 26), // day +7
            templateAmount: 1_850,
            templateNote: "Rent",
            templateCategoryID: rent.id,
            templateAccountID: checking.id
        ))

        let result = try await makeUseCase(
            accounts: accounts,
            transactions: transactions,
            recurring: recurring,
            categories: categories
        ).execute(dayCount: 30)

        #expect(result.startingBalance == 4_450) // 4200 + 250
        #expect(result.historyDayCount == 10)
        #expect(result.discretionaryExpenseTotal == 500) // 10 × 50; rent excluded
        #expect(result.averageDailyDiscretionarySpend == 50)

        // Manual day-30:
        // start 4450
        // −50 × 30 discretionary = −1500
        // +6400 salary on day 6
        // −1850 rent on day 7
        // → 4450 − 1500 + 6400 − 1850 = 7500
        #expect(result.balance(atDayOffset: 30) == 7_500)

        var running = result.startingBalance
        for point in result.points where point.dayOffset > 0 {
            running += point.delta
            #expect(point.balance == running)
        }
    }

    @Test("zero-history user: recurring only, discretionary average is zero")
    @MainActor
    func zeroHistoryUser() async throws {
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()

        try await accounts.create(AccountEntity(
            name: "Checking",
            type: .bank,
            balance: 1_000,
            currencyCode: "USD"
        ))
        let expense = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        try await categories.create(expense)
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 7, 29), // +10
            templateAmount: 100,
            templateNote: "Rent",
            templateCategoryID: expense.id,
            templateAccountID: UUID()
        ))

        let result = try await makeUseCase(
            accounts: accounts,
            transactions: transactions,
            recurring: recurring,
            categories: categories
        ).execute(dayCount: 20)

        #expect(result.historyDayCount == 0)
        #expect(result.averageDailyDiscretionarySpend == 0)
        #expect(result.balance(atDayOffset: 9) == 1_000)
        #expect(result.balance(atDayOffset: 10) == 900)
        #expect(result.balance(atDayOffset: 20) == 900)
    }

    @Test("rule ending mid-window does not schedule past endDate")
    @MainActor
    func ruleEndingMidWindow() async throws {
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()

        try await accounts.create(AccountEntity(
            name: "Checking",
            type: .bank,
            balance: 5_000,
            currencyCode: "USD"
        ))
        let expense = CategoryEntity(name: "Gym", icon: "dumbbell", type: .expense)
        try await categories.create(expense)

        let accountID = UUID()
        await recurring.seed(RecurringRuleEntity(
            frequency: .daily,
            nextDate: date(2026, 7, 20), // +1
            endDate: date(2026, 7, 24), // +5 inclusive
            templateAmount: 10,
            templateNote: "Gym",
            templateCategoryID: expense.id,
            templateAccountID: accountID
        ))

        // Need matching account id on rule — recreate with known id via seed after create
        // Rule already has accountID; account fetch doesn't need to match for forecast.

        let result = try await makeUseCase(
            accounts: accounts,
            transactions: transactions,
            recurring: recurring,
            categories: categories
        ).execute(dayCount: 15)

        // Days 1-5: −10 each; days 6-15: flat. No discretionary.
        #expect(result.averageDailyDiscretionarySpend == 0)
        #expect(result.balance(atDayOffset: 5) == 4_950)
        #expect(result.balance(atDayOffset: 15) == 4_950)
    }

    @Test("short history divides by available days, not 90")
    @MainActor
    func shortHistoryUsesAvailableDays() async throws {
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()

        try await accounts.create(AccountEntity(
            name: "Checking",
            type: .bank,
            balance: 100,
            currencyCode: "USD"
        ))
        let groceries = CategoryEntity(name: "Groceries", icon: "cart", type: .expense)
        try await categories.create(groceries)

        // Only 5 days of history, total discretionary 100 → avg 20
        for offset in 1...5 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            await transactions.seed(TransactionEntity(
                amount: 20,
                date: day,
                type: .expense,
                categoryID: groceries.id,
                accountID: UUID()
            ))
        }

        let result = try await makeUseCase(
            accounts: accounts,
            transactions: transactions,
            recurring: recurring,
            categories: categories
        ).execute(dayCount: 10)

        #expect(result.historyDayCount == 5)
        #expect(result.discretionaryExpenseTotal == 100)
        #expect(result.averageDailyDiscretionarySpend == 20)
        // Use Decimal literals — `100 - 20 * 10` as Int can fail Decimal #expect equality.
        #expect(result.balance(atDayOffset: 10) == Decimal(-100))
    }

    @Test("demo-shaped US dataset day-30 matches hand computation")
    @MainActor
    func demoUSDay30HandComputation() async throws {
        // Frozen "today" = 2026-07-19. Mirrors UITestDataSeeder US showcase amounts.
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()

        // Post-seed net worth (assets − liabilities) after demo showcase txs:
        // bank 13102.30 + cash 222.65 − card 1266.97 = 12057.98
        try await accounts.create(AccountEntity(
            name: "Chase Checking", type: .bank,
            balance: Decimal(string: "13102.30")!, currencyCode: "USD"
        ))
        try await accounts.create(AccountEntity(
            name: "Cash", type: .cash,
            balance: Decimal(string: "222.65")!, currencyCode: "USD"
        ))
        try await accounts.create(AccountEntity(
            name: "Amex Credit Card", type: .creditCard,
            balance: Decimal(string: "1266.97")!, currencyCode: "USD"
        ))

        let salary = CategoryEntity(name: "Salary", icon: "banknote", type: .income)
        let rent = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        let subs = CategoryEntity(name: "Subscriptions", icon: "tv", type: .expense)
        let groceries = CategoryEntity(name: "Groceries", icon: "cart", type: .expense)
        try await categories.create(salary)
        try await categories.create(rent)
        try await categories.create(subs)
        try await categories.create(groceries)

        // Earliest history day = June 1 → 48 days through July 19.
        // Discretionary total of all non-recurring demo expenses = 5192.02
        await transactions.seed(TransactionEntity(
            amount: Decimal(string: "5192.02")!,
            date: date(2026, 6, 1),
            type: .expense,
            categoryID: groceries.id,
            accountID: UUID()
        ))
        // Spread is irrelevant when totaling; one row on earliest day sets the window.

        let checkingID = UUID()
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 7, 25), // +6
            templateAmount: 6_400,
            templateNote: "Monthly Salary",
            templateCategoryID: salary.id,
            templateAccountID: checkingID
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 7, 26), // +7
            templateAmount: 1_850,
            templateNote: "Rent",
            templateCategoryID: rent.id,
            templateAccountID: checkingID
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(2026, 8, 10), // +22
            templateAmount: Decimal(string: "15.49")!,
            templateNote: "Netflix",
            templateCategoryID: subs.id,
            templateAccountID: checkingID
        ))

        let result = try await makeUseCase(
            accounts: accounts,
            transactions: transactions,
            recurring: recurring,
            categories: categories
        ).execute(dayCount: 90)

        let start = Decimal(string: "12057.98")!
        let discretionaryTotal = Decimal(string: "5192.02")!
        let historyDays = 48
        let avg = discretionaryTotal / Decimal(historyDays)

        #expect(result.startingBalance == start)
        #expect(result.historyDayCount == historyDays)
        #expect(result.discretionaryExpenseTotal == discretionaryTotal)
        #expect(result.averageDailyDiscretionarySpend == avg)

        // Hand computation for day 30 (2026-08-18) — apply the same daily steps the
        // chart uses. Do NOT use `avg * 30`: Decimal ÷ then × does not round-trip.
        var expectedDay30 = start
        for day in 1...30 {
            var delta = -avg
            if day == 6 { delta += 6_400 }
            if day == 7 { delta -= 1_850 }
            if day == 22 { delta -= Decimal(string: "15.49")! }
            expectedDay30 += delta
        }
        #expect(result.balance(atDayOffset: 30) == expectedDay30)

        // Running balance on the chart equals sequential sum of charted deltas.
        var running = start
        for point in result.points where point.dayOffset >= 1 && point.dayOffset <= 30 {
            running += point.delta
            #expect(point.balance == running)
        }
        #expect(running == expectedDay30)
    }

    // MARK: - Helpers

    @MainActor
    private func makeUseCase(
        accounts: MockAccountRepository,
        transactions: MockTransactionRepository,
        recurring: MockRecurringRuleRepository,
        categories: MockCategoryRepository
    ) -> CashFlowForecastUseCase {
        CashFlowForecastUseCase(
            accountRepository: accounts,
            transactionRepository: transactions,
            recurringRuleRepository: recurring,
            categoryRepository: categories,
            calendar: calendar,
            nowProvider: { self.today }
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
