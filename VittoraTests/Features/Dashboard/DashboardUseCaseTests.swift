import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Dashboard Use Case Tests")
struct DashboardUseCaseTests {

    // MARK: - Helpers

    private static func makeDashboardUseCase(
        transactions: [TransactionEntity] = [],
        accounts: [AccountEntity] = [],
        categories: [CategoryEntity] = [],
        budgets: [BudgetEntity] = [],
        recurringRules: [RecurringRuleEntity] = []
    ) async -> DashboardDataUseCase {
        let txRepo = MockTransactionRepository()
        let accountRepo = MockAccountRepository()
        let categoryRepo = MockCategoryRepository()
        let budgetRepo = MockBudgetRepository()
        let recurringRepo = MockRecurringRuleRepository()

        for t in transactions { await txRepo.seed(t) }
        for a in accounts { await accountRepo.seed(a) }
        for c in categories { await categoryRepo.seed(c) }
        for b in budgets { await budgetRepo.seed(b) }
        for r in recurringRules { await recurringRepo.seed(r) }

        return DashboardDataUseCase(
            transactionRepository: txRepo,
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            budgetRepository: budgetRepo,
            recurringRuleRepository: recurringRepo
        )
    }

    // MARK: - DashboardDataUseCase

    @MainActor
    @Suite("DashboardDataUseCase")
    struct DashboardDataUseCaseTests {

        @Test("Returns zero spending when no transactions")
        func testZeroSpendingWithNoTransactions() async throws {
            let useCase = await makeDashboardUseCase()
            let data = try await useCase.execute()

            #expect(data.todaySpending == 0)
            #expect(data.monthSpending == 0)
            #expect(data.monthIncome == 0)
        }

        @Test("Calculates today's spending from expense transactions today")
        func testTodaySpending() async throws {
            let todayExpense = TransactionEntity(amount: 50, date: .now, type: .expense)
            let pastExpense = TransactionEntity(
                amount: 200,
                date: Date(timeIntervalSinceNow: -86400 * 2),
                type: .expense
            )

            let useCase = await makeDashboardUseCase(transactions: [todayExpense, pastExpense])
            let data = try await useCase.execute()

            #expect(data.todaySpending == 50)
        }

        @Test("Calculates month spending from expense transactions this month")
        func testMonthSpending() async throws {
            let thisMonth = TransactionEntity(amount: 300, date: .now, type: .expense)
            let lastMonth = TransactionEntity(
                amount: 100,
                date: Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
                type: .expense
            )

            let useCase = await makeDashboardUseCase(transactions: [thisMonth, lastMonth])
            let data = try await useCase.execute()

            #expect(data.monthSpending == 300)
        }

        @Test("Calculates month income from income transactions this month")
        func testMonthIncome() async throws {
            let income = TransactionEntity(amount: 5000, date: .now, type: .income)
            let oldIncome = TransactionEntity(
                amount: 1000,
                date: Calendar.current.date(byAdding: .month, value: -1, to: .now)!,
                type: .income
            )

            let useCase = await makeDashboardUseCase(transactions: [income, oldIncome])
            let data = try await useCase.execute()

            #expect(data.monthIncome == 5000)
        }

        @Test("Calculates net worth from asset and liability accounts")
        func testNetWorthCalculation() async throws {
            let checking = AccountEntity(name: "Checking", type: .bank, balance: Decimal(10000))
            let savings = AccountEntity(name: "Savings", type: .bank, balance: Decimal(5000))
            let credit = AccountEntity(name: "Visa", type: .creditCard, balance: Decimal(2000))

            let useCase = await makeDashboardUseCase(accounts: [checking, savings, credit])
            let data = try await useCase.execute()

            #expect(data.netWorth == 13000)
        }

        @Test("Excludes archived accounts from account summary")
        func testExcludesArchivedAccounts() async throws {
            let active = AccountEntity(name: "Active", type: .bank, isArchived: false)
            let archived = AccountEntity(name: "Old", type: .bank, isArchived: true)

            let useCase = await makeDashboardUseCase(accounts: [active, archived])
            let data = try await useCase.execute()

            #expect(data.accountSummary.count == 1)
            #expect(data.accountSummary[0].name == "Active")
        }

        @Test("Returns at most 5 recent transactions sorted by date descending")
        func testRecentTransactionsLimitedToFive() async throws {
            var transactions: [TransactionEntity] = []
            for i in 0..<7 {
                transactions.append(TransactionEntity(
                    amount: Decimal(i * 10 + 10),
                    date: Date(timeIntervalSinceNow: -Double(i) * 3600),
                    type: .expense
                ))
            }

            let useCase = await makeDashboardUseCase(transactions: transactions)
            let data = try await useCase.execute()

            #expect(data.recentTransactions.count == 5)
            // Most recent first
            #expect(data.recentTransactions[0].date >= data.recentTransactions[1].date)
        }

        @Test("Returns at most 3 upcoming recurring rules sorted by nextDate")
        func testUpcomingRecurringLimitedToThree() async throws {
            var rules: [RecurringRuleEntity] = []
            for i in 1...5 {
                rules.append(RecurringRuleEntity(
                    frequency: .monthly,
                    nextDate: Date(timeIntervalSinceNow: Double(i) * 86400),
                    isActive: true,
                    templateAmount: Decimal(i * 100)
                ))
            }

            let useCase = await makeDashboardUseCase(recurringRules: rules)
            let data = try await useCase.execute()

            #expect(data.upcomingRecurring.count == 3)
            #expect(data.upcomingRecurring[0].nextDate <= data.upcomingRecurring[1].nextDate)
        }

        @Test("Excludes inactive recurring rules from upcoming")
        func testExcludesInactiveRules() async throws {
            let active = RecurringRuleEntity(
                frequency: .monthly,
                nextDate: Date(timeIntervalSinceNow: 86400),
                isActive: true,
                templateAmount: 100
            )
            let inactive = RecurringRuleEntity(
                frequency: .monthly,
                nextDate: Date(timeIntervalSinceNow: 86400),
                isActive: false,
                templateAmount: 200
            )

            let useCase = await makeDashboardUseCase(recurringRules: [active, inactive])
            let data = try await useCase.execute()

            #expect(data.upcomingRecurring.count == 1)
        }

        @Test("Budget progress is zero when no active budgets")
        func testBudgetProgressZeroWithNoBudgets() async throws {
            let useCase = await makeDashboardUseCase()
            let data = try await useCase.execute()

            #expect(data.monthBudgetProgress == 0.0)
        }

        @Test("Budget progress is capped at 1.0")
        func testBudgetProgressCappedAtOne() async throws {
            // Budget with spent exceeding amount
            let budget = BudgetEntity(amount: 100, spent: 200, period: .monthly)
            let useCase = await makeDashboardUseCase(budgets: [budget])
            let data = try await useCase.execute()

            #expect(data.monthBudgetProgress <= 1.0)
        }

        @Test("Top categories are ordered by spend descending")
        func testTopCategoriesOrderedBySpend() async throws {
            let cat1 = CategoryEntity(name: "Food", icon: "fork.knife", type: .expense)
            let cat2 = CategoryEntity(name: "Transport", icon: "car.fill", type: .expense)

            let t1 = TransactionEntity(amount: 300, date: .now, type: .expense, categoryID: cat1.id)
            let t2 = TransactionEntity(amount: 100, date: .now, type: .expense, categoryID: cat2.id)

            let useCase = await makeDashboardUseCase(
                transactions: [t1, t2],
                categories: [cat1, cat2]
            )
            let data = try await useCase.execute()

            #expect(data.topCategories.count == 2)
            #expect(data.topCategories[0].amount >= data.topCategories[1].amount)
            #expect(data.topCategories[0].category.name == "Food")
        }
    }

    // MARK: - MonthComparisonUseCase

    @MainActor
    @Suite("MonthComparisonUseCase")
    struct MonthComparisonUseCaseTests {

        @Test("Calculates spending increase percentage")
        func testSpendingIncreasePercent() async throws {
            let calendar = Calendar.current
            let currentMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: .now)
            )!
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!

            // Current month: 150, Last month: 100 → +50%
            let current = TransactionEntity(
                amount: 150, date: currentMonthStart, type: .expense
            )
            let last = TransactionEntity(
                amount: 100, date: lastMonthStart, type: .expense
            )

            let repo = MockTransactionRepository()
            await repo.seed(current)
            await repo.seed(last)

            let useCase = MonthComparisonUseCase(transactionRepository: repo)
            let comparison = try await useCase.execute()

            #expect(comparison.spendingChangePercent > 0)
            #expect(comparison.currentMonthSpending == 150)
            #expect(comparison.lastMonthSpending == 100)
        }

        @Test("Spending change is 100% when last month was zero and current is positive")
        func testSpendingChangeWhenLastMonthZero() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 100, date: .now, type: .expense))

            let useCase = MonthComparisonUseCase(transactionRepository: repo)
            let comparison = try await useCase.execute()

            #expect(comparison.spendingChangePercent == 100.0)
        }

        @Test("Savings rate is clamped to zero when spending exceeds income")
        func testSavingsRateClampedAtZero() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 2000, date: .now, type: .expense))
            await repo.seed(TransactionEntity(amount: 1000, date: .now, type: .income))

            let useCase = MonthComparisonUseCase(transactionRepository: repo)
            let comparison = try await useCase.execute()

            #expect(comparison.savingsRate == 0.0)
        }

        @Test("Savings rate is zero when there is no income")
        func testSavingsRateWithNoIncome() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 500, date: .now, type: .expense))

            let useCase = MonthComparisonUseCase(transactionRepository: repo)
            let comparison = try await useCase.execute()

            #expect(comparison.savingsRate == 0.0)
        }

        @Test("Savings rate is positive when income exceeds spending")
        func testPositiveSavingsRate() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 1000, date: .now, type: .income))
            await repo.seed(TransactionEntity(amount: 600, date: .now, type: .expense))

            let useCase = MonthComparisonUseCase(transactionRepository: repo)
            let comparison = try await useCase.execute()

            // savingsRate = (1000 - 600) / 1000 = 0.4
            #expect(comparison.savingsRate > 0)
            #expect(comparison.savingsRate <= 1.0)
        }

        @Test("Returns zero comparison when no transactions")
        func testZeroComparisonWithNoTransactions() async throws {
            let useCase = MonthComparisonUseCase(transactionRepository: MockTransactionRepository())
            let comparison = try await useCase.execute()

            #expect(comparison.currentMonthSpending == 0)
            #expect(comparison.lastMonthSpending == 0)
            #expect(comparison.currentMonthIncome == 0)
            #expect(comparison.lastMonthIncome == 0)
            #expect(comparison.savingsRate == 0.0)
        }
    }
}
