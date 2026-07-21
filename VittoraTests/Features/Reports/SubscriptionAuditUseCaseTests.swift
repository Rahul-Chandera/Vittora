import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Subscription Audit Use Case Tests")
struct SubscriptionAuditUseCaseTests {
    private let now = makeDate(year: 2026, month: 7, day: 15)
    private let netflixAmount = Decimal(string: "15.49")!
    private let pausedAmount = Decimal(string: "9.99")!
    private let endedAmount = Decimal(string: "12.99")!

    @Test("includes active expense rules sorted by monthly cost descending")
    func sortsByMonthlyCostDescending() async throws {
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()

        let subscriptions = CategoryEntity(name: "Subscriptions", icon: "tv.fill", type: .expense)
        let rent = CategoryEntity(name: "Rent", icon: "house.fill", type: .expense)
        try await categories.create(subscriptions)
        try await categories.create(rent)

        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            templateAmount: netflixAmount,
            templateNote: "Netflix",
            templateCategoryID: subscriptions.id,
            templateAccountID: UUID()
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            templateAmount: 1_850,
            templateNote: "Rent",
            templateCategoryID: rent.id,
            templateAccountID: UUID()
        ))

        let report = try await makeUseCase(
            recurring: recurring,
            categories: categories,
            transactions: transactions
        ).execute()

        #expect(report.rows.count == 2)
        #expect(report.rows[0].name == "Rent")
        #expect(report.rows[1].name == "Netflix")
        #expect(report.rows[1].monthlyCost == netflixAmount)
        #expect(report.monthlyTotal == report.rows.reduce(0) { $0 + $1.monthlyCost })
        #expect(report.annualTotal == report.rows.reduce(0) { $0 + $1.annualCost })
    }

    @Test("yearly subscription annual total equals billed amount exactly (no ÷12×12 drift)")
    func yearlySubscriptionAnnualTotalExact() async throws {
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()

        let subscriptions = CategoryEntity(name: "Subscriptions", icon: "tv.fill", type: .expense)
        try await categories.create(subscriptions)

        await recurring.seed(RecurringRuleEntity(
            frequency: .yearly,
            nextDate: now,
            templateAmount: 899,
            templateNote: "Annual Plan",
            templateCategoryID: subscriptions.id,
            templateAccountID: UUID()
        ))

        let report = try await makeUseCase(
            recurring: recurring,
            categories: categories,
            transactions: transactions
        ).execute()

        let expected = Decimal(string: "899")!
        #expect(report.rows.count == 1)
        #expect(report.rows[0].annualCost == expected)
        #expect(report.annualTotal == expected)
        #expect(report.monthlyTotal == report.rows[0].monthlyCost)
    }

    @Test("excludes paused and ended rules")
    func excludesPausedAndEnded() async throws {
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()
        let expense = CategoryEntity(name: "Subscriptions", icon: "tv.fill", type: .expense)
        try await categories.create(expense)

        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            isActive: false,
            templateAmount: pausedAmount,
            templateNote: "Paused",
            templateCategoryID: expense.id,
            templateAccountID: UUID()
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            isActive: true,
            endDate: makeDate(year: 2026, month: 1, day: 1),
            templateAmount: endedAmount,
            templateNote: "Ended",
            templateCategoryID: expense.id,
            templateAccountID: UUID()
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            templateAmount: netflixAmount,
            templateNote: "Netflix",
            templateCategoryID: expense.id,
            templateAccountID: UUID()
        ))

        let report = try await makeUseCase(
            recurring: recurring,
            categories: categories,
            transactions: transactions
        ).execute()

        #expect(report.rows.count == 1)
        #expect(report.rows[0].name == "Netflix")
    }

    @Test("excludes income recurring rules")
    func excludesIncomeRules() async throws {
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()
        let salary = CategoryEntity(name: "Salary", icon: "banknote.fill", type: .income)
        let subscriptions = CategoryEntity(name: "Subscriptions", icon: "tv.fill", type: .expense)
        try await categories.create(salary)
        try await categories.create(subscriptions)

        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            templateAmount: 6_400,
            templateNote: "Monthly Salary",
            templateCategoryID: salary.id,
            templateAccountID: UUID()
        ))
        await recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: now,
            templateAmount: netflixAmount,
            templateNote: "Netflix",
            templateCategoryID: subscriptions.id,
            templateAccountID: UUID()
        ))

        let report = try await makeUseCase(
            recurring: recurring,
            categories: categories,
            transactions: transactions
        ).execute()

        #expect(report.rows.map(\.name) == ["Netflix"])
        #expect(report.monthlyTotal == netflixAmount)
        #expect(report.annualTotal == netflixAmount * 12)
        #expect(report.annualTotal == report.rows.reduce(0) { $0 + $1.annualCost })
    }

    @Test("empty when no active expense rules")
    func emptyWhenNoExpenseRules() async throws {
        let report = try await makeUseCase(
            recurring: MockRecurringRuleRepository(),
            categories: MockCategoryRepository(),
            transactions: MockTransactionRepository()
        ).execute()

        #expect(report.rows.isEmpty)
        #expect(report.monthlyTotal == 0)
        #expect(report.annualTotal == 0)
    }

    @Test("last ran uses latest linked transaction date")
    func lastRanFromLinkedTransaction() async throws {
        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()
        let expense = CategoryEntity(name: "Subscriptions", icon: "tv.fill", type: .expense)
        try await categories.create(expense)

        let ruleID = UUID()
        await recurring.seed(RecurringRuleEntity(
            id: ruleID,
            frequency: .monthly,
            nextDate: now,
            templateAmount: netflixAmount,
            templateNote: "Netflix",
            templateCategoryID: expense.id,
            templateAccountID: UUID()
        ))

        let earlier = makeDate(year: 2026, month: 5, day: 10)
        let later = makeDate(year: 2026, month: 6, day: 10)
        try await transactions.create(TransactionEntity(
            amount: netflixAmount,
            date: earlier,
            type: .expense,
            recurringRuleID: ruleID
        ))
        try await transactions.create(TransactionEntity(
            amount: netflixAmount,
            date: later,
            type: .expense,
            recurringRuleID: ruleID
        ))

        let report = try await makeUseCase(
            recurring: recurring,
            categories: categories,
            transactions: transactions
        ).execute()

        #expect(report.rows.first?.lastRan == later)
    }

    private func makeUseCase(
        recurring: MockRecurringRuleRepository,
        categories: MockCategoryRepository,
        transactions: MockTransactionRepository
    ) -> SubscriptionAuditUseCase {
        SubscriptionAuditUseCase(
            recurringRuleRepository: recurring,
            categoryRepository: categories,
            transactionRepository: transactions,
            nowProvider: { now }
        )
    }
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day))
        ?? Date(timeIntervalSince1970: 0)
}
