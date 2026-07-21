import Foundation
import Testing
import SwiftData
import VittoraCore

@Suite("WidgetDataProvider", .serialized)
struct WidgetDataProviderTests {

    private func makeProvider() throws -> (WidgetDataProvider, ModelContainer) {
        let container = try ModelContainerConfig.makePreviewContainer()
        return (WidgetDataProvider(container: container), container)
    }

    /// Pin currency so parallel suites cannot race `CurrencyDefaults.code`
    /// (App Group mirror vs `.standard`) mid-assertion.
    private func withPinnedCurrency<T: Sendable>(
        _ code: String = "USD",
        _ body: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await TestCurrencyLock.shared.run {
            let key = AppUserDefaults.StandardKey.currencyCode
            let originalStandard = UserDefaults.standard.string(forKey: key)
            let originalGroup = AppUserDefaults.appGroup.string(forKey: key)
            defer {
                restore(key, originalStandard, on: .standard)
                restore(key, originalGroup, on: AppUserDefaults.appGroup)
            }
            UserDefaults.standard.set(code, forKey: key)
            AppUserDefaults.appGroup.set(code, forKey: key)
            return try await body()
        }
    }

    private func restore(_ key: String, _ value: String?, on defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    @Test("todaySpending sums today's expenses only")
    func todaySpendingMatchesSeededExpenses() async throws {
        try await withPinnedCurrency {
            let (provider, container) = try makeProvider()
            let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)

            let todayExpense = TransactionEntity(
                amount: Decimal(string: "42.5") ?? 0,
                date: .now,
                type: .expense
            )
            let todayIncome = TransactionEntity(amount: 100, date: .now, type: .income)
            let yesterdayExpense = TransactionEntity(
                amount: 99,
                date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                type: .expense
            )

            try await transactionRepo.create(todayExpense)
            try await transactionRepo.create(todayIncome)
            try await transactionRepo.create(yesterdayExpense)

            let result = try await provider.todaySpending()

            #expect(result.amount == Decimal(425) / 10)
            #expect(result.currencyCode == "USD")
        }
    }

    @Test("todaySpendingSnapshot includes yesterday and 7-day series")
    func todaySpendingSnapshotIncludesTrendSeries() async throws {
        try await withPinnedCurrency {
            let (provider, container) = try makeProvider()
            let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: .now)

            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset - 6, to: startOfToday) ?? startOfToday
                try await transactionRepo.create(
                    TransactionEntity(amount: Decimal(dayOffset + 1), date: date, type: .expense)
                )
            }

            let snapshot = try await provider.todaySpendingSnapshot(
                now: startOfToday.addingTimeInterval(12 * 3600),
                calendar: calendar
            )

            #expect(snapshot.last7DayAmounts.count == 7)
            #expect(snapshot.todayAmount == 7)
            #expect(snapshot.yesterdayAmount == 6)
            #expect(snapshot.last7DayAmounts == [1, 2, 3, 4, 5, 6, 7])
            #expect(snapshot.changePercentVsYesterday != nil)
        }
    }

    @Test("budgetSnapshot totals active budget amounts and computed spend")
    func budgetSnapshotMatchesSeededBudgets() async throws {
        try await withPinnedCurrency {
            let (provider, container) = try makeProvider()
            let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
            let budgetRepo = SwiftDataBudgetRepository(modelContainer: container)

            let categoryID = UUID()
            let budget = BudgetEntity(
                amount: 1000,
                period: .monthly,
                startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                categoryID: categoryID
            )
            try await budgetRepo.create(budget)

            let expense = TransactionEntity(
                amount: 250,
                date: .now,
                type: .expense,
                categoryID: categoryID
            )
            try await transactionRepo.create(expense)

            let snapshot = try await provider.budgetSnapshot()

            #expect(snapshot.spent == 250)
            #expect(snapshot.total == 1000)
            #expect(snapshot.currencyCode == "USD")
        }
    }

    @Test("budgetRemainingSnapshot returns top categories by spent")
    func budgetRemainingSnapshotTopCategories() async throws {
        try await withPinnedCurrency {
            let (provider, container) = try makeProvider()
            let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
            let budgetRepo = SwiftDataBudgetRepository(modelContainer: container)
            let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)

            let food = CategoryEntity(name: "Food", icon: "fork.knife", colorHex: "#34C759")
            let transport = CategoryEntity(name: "Transport", icon: "car", colorHex: "#007AFF")
            let fun = CategoryEntity(name: "Fun", icon: "gamecontroller", colorHex: "#FF9500")
            try await categoryRepo.create(food)
            try await categoryRepo.create(transport)
            try await categoryRepo.create(fun)

            let start = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            try await budgetRepo.create(BudgetEntity(amount: 400, period: .monthly, startDate: start, categoryID: food.id))
            try await budgetRepo.create(BudgetEntity(amount: 200, period: .monthly, startDate: start, categoryID: transport.id))
            try await budgetRepo.create(BudgetEntity(amount: 100, period: .monthly, startDate: start, categoryID: fun.id))

            try await transactionRepo.create(TransactionEntity(amount: 300, date: .now, type: .expense, categoryID: food.id))
            try await transactionRepo.create(TransactionEntity(amount: 50, date: .now, type: .expense, categoryID: transport.id))
            try await transactionRepo.create(TransactionEntity(amount: 80, date: .now, type: .expense, categoryID: fun.id))

            let snapshot = try await provider.budgetRemainingSnapshot()

            #expect(snapshot.hasBudgets)
            #expect(snapshot.spent == 430)
            #expect(snapshot.total == 700)
            #expect(snapshot.categories.count == 3)
            #expect(snapshot.categories.map(\.name) == ["Food", "Fun", "Transport"])
        }
    }

    @Test("empty store returns zero spending and budget totals")
    func emptyStoreReturnsZeros() async throws {
        try await withPinnedCurrency {
            let (provider, _) = try makeProvider()

            let spending = try await provider.todaySpending()
            let snapshot = try await provider.budgetSnapshot()
            let remaining = try await provider.budgetRemainingSnapshot()

            #expect(spending.amount == 0)
            #expect(snapshot.spent == 0)
            #expect(snapshot.total == 0)
            #expect(remaining.hasBudgets == false)
            #expect(spending.currencyCode == "USD")
            #expect(snapshot.currencyCode == "USD")
        }
    }
}

@Suite("WidgetTimelineDates")
struct WidgetTimelineDatesTests {

    @Test("entryDates includes now and next midnight for a fixed now")
    func midnightRolloverEntryExists() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 19
        components.hour = 15
        components.minute = 37
        let now = calendar.date(from: components) ?? .now

        let dates = WidgetTimelineDates.entryDates(now: now, calendar: calendar)

        #expect(dates.count == 2)
        #expect(dates[0] == now)

        let nextMidnight = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))
        #expect(dates[1] == nextMidnight)
    }

    @Test("entryDates next midnight is start of following day near midnight")
    func nearMidnightStillRollsToNextDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 19, hour: 23, minute: 59)) ?? .now
        let dates = WidgetTimelineDates.entryDates(now: now, calendar: calendar)

        #expect(dates[1] == calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
    }
}
