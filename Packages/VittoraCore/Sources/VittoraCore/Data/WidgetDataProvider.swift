import Foundation
import SwiftData

/// Read-only spending/budget queries for WidgetKit (and future App Intents).
/// Opens the App Group store without migrations, writes, or CloudKit.
public struct WidgetDataProvider: Sendable {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    /// Opens the shared on-disk store read-only for extension processes.
    public static func makeSharedReadOnly() throws -> WidgetDataProvider {
        WidgetDataProvider(container: try ModelContainerConfig.makeReadOnlyContainer())
    }

    /// Today's expense total, matching Dashboard's definition.
    public func todaySpending() async throws -> (amount: Decimal, currencyCode: String) {
        let snapshot = try await todaySpendingSnapshot()
        return (snapshot.todayAmount, snapshot.currencyCode)
    }

    /// Today + yesterday + trailing 7-day expense totals for Home Screen widgets.
    public func todaySpendingSnapshot(
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws -> TodaySpendingSnapshot {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOf7DayWindow = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

        let filter = TransactionFilter(
            dateRange: startOf7DayWindow...now,
            types: Set([.expense])
        )
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        var dayTotals = Array(repeating: Decimal(0), count: 7)
        for transaction in transactions {
            let dayStart = calendar.startOfDay(for: transaction.date)
            guard let offset = calendar.dateComponents([.day], from: startOf7DayWindow, to: dayStart).day,
                  offset >= 0, offset < 7 else { continue }
            dayTotals[offset] += transaction.amount
        }

        let todayAmount = dayTotals[6]
        let yesterdayAmount: Decimal
        if startOfYesterday >= startOf7DayWindow {
            yesterdayAmount = dayTotals[5]
        } else {
            yesterdayAmount = 0
        }

        return TodaySpendingSnapshot(
            todayAmount: todayAmount,
            yesterdayAmount: yesterdayAmount,
            last7DayAmounts: dayTotals,
            currencyCode: CurrencyDefaults.code
        )
    }

    /// Active budgets' spent/total for the current period, matching Dashboard.
    public func budgetSnapshot() async throws -> (spent: Decimal, total: Decimal, currencyCode: String) {
        let snapshot = try await budgetRemainingSnapshot()
        return (snapshot.spent, snapshot.total, snapshot.currencyCode)
    }

    /// Monthly budget remaining + top category progress for Home Screen widgets.
    /// Semantics match `BudgetListViewModel` with `selectedPeriod == .monthly`:
    /// overall = sum(spent) / sum(amount).
    public func budgetRemainingSnapshot() async throws -> BudgetRemainingSnapshot {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: container)
        let categoryRepository = SwiftDataCategoryRepository(modelContainer: container)

        let categories = try await categoryRepository.fetchAll()
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let active = try await budgetRepository.fetchActive()
        let monthly = active.filter { $0.period == .monthly }

        var rows: [BudgetCategoryProgress] = []
        rows.reserveCapacity(monthly.count)

        var totalSpent: Decimal = 0
        var totalBudget: Decimal = 0
        for budget in monthly {
            let spent = try await spent(for: budget, transactionRepository: transactionRepository)
            totalBudget += budget.amount
            totalSpent += spent
            let name = budget.categoryID.flatMap { categoriesByID[$0]?.displayName }
                ?? String(localized: "Overall")
            let colorHex = budget.categoryID.flatMap { categoriesByID[$0]?.colorHex }
                ?? "#34C759"
            rows.append(
                BudgetCategoryProgress(
                    name: name,
                    spent: spent,
                    amount: budget.amount,
                    colorHex: colorHex
                )
            )
        }

        let topCategories = Array(
            rows.sorted { $0.spent > $1.spent }.prefix(3)
        )

        return BudgetRemainingSnapshot(
            spent: totalSpent,
            total: totalBudget,
            currencyCode: CurrencyDefaults.code,
            categories: topCategories,
            hasBudgets: !monthly.isEmpty
        )
    }

    /// Same period/category filtering as `FetchBudgetsUseCase` in the app target.
    private func spent(
        for budget: BudgetEntity,
        transactionRepository: SwiftDataTransactionRepository
    ) async throws -> Decimal {
        let dateRange = budget.period.dateRange(startingFrom: budget.startDate)
        let filter = TransactionFilter(
            dateRange: dateRange,
            types: Set([.expense]),
            categoryIDs: budget.categoryID.map { Set([$0]) }
        )
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        return transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }
}

// MARK: - Snapshots

public struct TodaySpendingSnapshot: Sendable, Equatable {
    public let todayAmount: Decimal
    public let yesterdayAmount: Decimal
    /// Oldest → newest, length 7, last element is today.
    public let last7DayAmounts: [Decimal]
    public let currencyCode: String

    public init(
        todayAmount: Decimal,
        yesterdayAmount: Decimal,
        last7DayAmounts: [Decimal],
        currencyCode: String
    ) {
        self.todayAmount = todayAmount
        self.yesterdayAmount = yesterdayAmount
        self.last7DayAmounts = last7DayAmounts
        self.currencyCode = currencyCode
    }

    /// Percent change vs yesterday. `nil` when both days are zero.
    public var changePercentVsYesterday: Double? {
        if yesterdayAmount == 0 {
            return todayAmount == 0 ? nil : 100
        }
        let delta = todayAmount - yesterdayAmount
        return Double(truncating: (delta / yesterdayAmount * 100) as NSDecimalNumber)
    }
}

public struct BudgetCategoryProgress: Sendable, Equatable {
    public let name: String
    public let spent: Decimal
    public let amount: Decimal
    public let colorHex: String

    public init(name: String, spent: Decimal, amount: Decimal, colorHex: String) {
        self.name = name
        self.spent = spent
        self.amount = amount
        self.colorHex = colorHex
    }

    public var remaining: Decimal { amount - spent }

    public var progress: Double {
        guard amount > 0 else { return 0 }
        return min(Double(truncating: (spent / amount) as NSDecimalNumber), 2.0)
    }
}

public struct BudgetRemainingSnapshot: Sendable, Equatable {
    public let spent: Decimal
    public let total: Decimal
    public let currencyCode: String
    public let categories: [BudgetCategoryProgress]
    public let hasBudgets: Bool

    public init(
        spent: Decimal,
        total: Decimal,
        currencyCode: String,
        categories: [BudgetCategoryProgress],
        hasBudgets: Bool
    ) {
        self.spent = spent
        self.total = total
        self.currencyCode = currencyCode
        self.categories = categories
        self.hasBudgets = hasBudgets
    }

    public var remaining: Decimal { total - spent }

    public var progress: Double {
        guard total > 0 else { return 0 }
        return Double(truncating: (spent / total) as NSDecimalNumber)
    }
}

// MARK: - Timeline dates

/// Shared midnight-boundary timeline policy for Home Screen widgets.
public enum WidgetTimelineDates: Sendable {
    /// `[now, nextMidnight]` — pair with `TimelineReloadPolicy.atEnd` so today's
    /// spend resets when the day rolls over.
    public static func entryDates(now: Date, calendar: Calendar = .current) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(24 * 60 * 60)
        return [now, nextMidnight]
    }
}
