import Foundation

/// One category row shown on Year in Review (top N plus an optional Other rollup).
public struct YearInReviewCategoryShare: Equatable, Sendable, Identifiable {
    public nonisolated var id: String { name }
    public nonisolated let name: String
    public nonisolated let amount: Decimal
    /// Whole-percent share of the displayed year total; all rows' shares sum to 100.
    public nonisolated let sharePercent: Int

    public nonisolated init(name: String, amount: Decimal, sharePercent: Int) {
        self.name = name
        self.amount = amount
        self.sharePercent = sharePercent
    }
}

public struct YearInReviewMonthHighlight: Equatable, Sendable {
    public nonisolated let monthStart: Date
    public nonisolated let amount: Decimal
    public nonisolated let topCategoryName: String?
    public nonisolated let topCategoryAmount: Decimal

    public nonisolated init(
        monthStart: Date,
        amount: Decimal,
        topCategoryName: String?,
        topCategoryAmount: Decimal
    ) {
        self.monthStart = monthStart
        self.amount = amount
        self.topCategoryName = topCategoryName
        self.topCategoryAmount = topCategoryAmount
    }
}

public struct YearInReviewPayeeShare: Equatable, Sendable, Identifiable {
    public nonisolated var id: String { name }
    public nonisolated let name: String
    public nonisolated let amount: Decimal

    public nonisolated init(name: String, amount: Decimal) {
        self.name = name
        self.amount = amount
    }
}

public struct YearInReviewMonthlyPoint: Equatable, Sendable, Identifiable {
    public nonisolated var id: Date { monthStart }
    public nonisolated let monthStart: Date
    public nonisolated let amount: Decimal

    public nonisolated init(monthStart: Date, amount: Decimal) {
        self.monthStart = monthStart
        self.amount = amount
    }
}

public struct YearInReviewSummary: Equatable, Sendable {
    public nonisolated let year: Int
    public nonisolated let currencyCode: String
    /// True when expenses exist in other currencies that were excluded from totals.
    public nonisolated let scopedToPrimaryCurrency: Bool
    public nonisolated let totalSpent: Decimal
    public nonisolated let monthlySpend: [YearInReviewMonthlyPoint]
    public nonisolated let topCategories: [YearInReviewCategoryShare]
    public nonisolated let biggestMonth: YearInReviewMonthHighlight?
    public nonisolated let topPayees: [YearInReviewPayeeShare]
    public nonisolated let savingsContributed: Decimal
    public nonisolated let goalsCompleted: Int
    public nonisolated let longestStreakDays: Int
    public nonisolated let transactionCount: Int
    public nonisolated let firstTransactionDate: Date?

    public nonisolated init(
        year: Int,
        currencyCode: String,
        scopedToPrimaryCurrency: Bool,
        totalSpent: Decimal,
        monthlySpend: [YearInReviewMonthlyPoint],
        topCategories: [YearInReviewCategoryShare],
        biggestMonth: YearInReviewMonthHighlight?,
        topPayees: [YearInReviewPayeeShare],
        savingsContributed: Decimal,
        goalsCompleted: Int,
        longestStreakDays: Int,
        transactionCount: Int,
        firstTransactionDate: Date?
    ) {
        self.year = year
        self.currencyCode = currencyCode
        self.scopedToPrimaryCurrency = scopedToPrimaryCurrency
        self.totalSpent = totalSpent
        self.monthlySpend = monthlySpend
        self.topCategories = topCategories
        self.biggestMonth = biggestMonth
        self.topPayees = topPayees
        self.savingsContributed = savingsContributed
        self.goalsCompleted = goalsCompleted
        self.longestStreakDays = longestStreakDays
        self.transactionCount = transactionCount
        self.firstTransactionDate = firstTransactionDate
    }
}

/// Pure Year in Review math. Callers inject `today` — never reads `Date()`.
public enum YearInReviewMath {
    public static let minimumTransactionCount = 20
    public static let minimumHistoryMonths = 2
    public static let topCategoryLimit = 4
    public static let topPayeeLimit = 5
    /// Matches `FiftyThirtyTwentyReportUseCase.savingsContributionTag` in the app target.
    public static let savingsContributionTag = "savings-goal-contribution"

    // MARK: - Readiness & years

    public nonisolated static func isReady(
        transactions: [TransactionEntity],
        today: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let eligible = transactions.filter { $0.date <= today && $0.type != .transfer }
        guard eligible.count >= minimumTransactionCount else { return false }
        let months = Set(eligible.map { calendar.dateComponents([.year, .month], from: $0.date) })
        return months.count >= minimumHistoryMonths
    }

    public nonisolated static func availableYears(
        transactions: [TransactionEntity],
        today: Date,
        calendar: Calendar = .current
    ) -> [Int] {
        let years = Set(
            transactions
                .filter { $0.date <= today && $0.type != .transfer }
                .map { calendar.component(.year, from: $0.date) }
        )
        return years.sorted(by: >)
    }

    /// Preferred year: `requested` if it has data; else current calendar year if it has data;
    /// else the most recent year with data.
    public nonisolated static func resolveYear(
        requested: Int?,
        transactions: [TransactionEntity],
        today: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let years = availableYears(transactions: transactions, today: today, calendar: calendar)
        guard !years.isEmpty else { return nil }
        if let requested, years.contains(requested) { return requested }
        let current = calendar.component(.year, from: today)
        if years.contains(current) { return current }
        return years.first
    }

    // MARK: - Summary

    public nonisolated static func summary(
        transactions: [TransactionEntity],
        goals: [SavingsGoalEntity],
        categoryNames: [UUID: String],
        payeeNames: [UUID: String],
        year: Int,
        preferredCurrencyCode: String,
        today: Date,
        calendar: Calendar = .current,
        savingsContributionTag: String = savingsContributionTag
    ) -> YearInReviewSummary? {
        let inYear = transactions.filter {
            $0.date <= today
                && calendar.component(.year, from: $0.date) == year
                && $0.type != .transfer
        }
        guard !inYear.isEmpty else { return nil }

        let expensesAllCurrencies = inYear.filter { $0.type == .expense && $0.amount > 0 }
        let currencyCodes = Set(expensesAllCurrencies.map(\.currencyCode))
        let primary = primaryCurrency(
            among: expensesAllCurrencies,
            preferred: preferredCurrencyCode
        )
        let scoped = currencyCodes.count > 1
        let expenses = expensesAllCurrencies.filter { $0.currencyCode == primary }

        let totalSpent = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let monthlySpend = monthlyPoints(expenses: expenses, year: year, calendar: calendar)
        let topCategories = categoryShares(
            expenses: expenses,
            categoryNames: categoryNames,
            totalSpent: totalSpent
        )
        let biggestMonth = biggestMonthHighlight(
            expenses: expenses,
            categoryNames: categoryNames,
            calendar: calendar
        )
        let topPayees = payeeShares(expenses: expenses, payeeNames: payeeNames)

        let savings = inYear
            .filter {
                $0.currencyCode == primary
                    && $0.tags.contains(savingsContributionTag)
                    && $0.amount > 0
            }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let goalsCompleted = goals.filter { $0.status == .achieved || $0.isAchieved }.count
        let streak = longestStreakDays(in: inYear, calendar: calendar)
        let firstDate = transactions
            .filter { $0.date <= today && $0.type != .transfer }
            .map(\.date)
            .min()

        return YearInReviewSummary(
            year: year,
            currencyCode: primary,
            scopedToPrimaryCurrency: scoped,
            totalSpent: totalSpent,
            monthlySpend: monthlySpend,
            topCategories: topCategories,
            biggestMonth: biggestMonth,
            topPayees: topPayees,
            savingsContributed: savings,
            goalsCompleted: goalsCompleted,
            longestStreakDays: streak,
            transactionCount: inYear.count,
            firstTransactionDate: firstDate
        )
    }

    /// Displayed category amounts must sum to the displayed year total (no inverse math).
    public nonisolated static func displayedCategoryAmountsSumToTotal(
        categories: [YearInReviewCategoryShare],
        totalSpent: Decimal
    ) -> Bool {
        let sum = categories.reduce(Decimal(0)) { $0 + $1.amount }
        return sum == totalSpent
    }

    /// Displayed whole-percent shares must sum to 100 when there is spending.
    public nonisolated static func displayedSharesSumTo100(
        categories: [YearInReviewCategoryShare]
    ) -> Bool {
        guard !categories.isEmpty else { return true }
        return categories.reduce(0) { $0 + $1.sharePercent } == 100
    }

    /// Largest-remainder whole percents from positive amounts; empty → empty.
    public nonisolated static func displayedPercentageShares(amounts: [Decimal]) -> [Int] {
        guard !amounts.isEmpty else { return [] }
        let total = amounts.reduce(Decimal(0), +)
        guard total > 0 else { return Array(repeating: 0, count: amounts.count) }

        struct Row {
            let index: Int
            let floor: Int
            let remainder: Decimal
        }

        var rows: [Row] = []
        rows.reserveCapacity(amounts.count)
        for (index, amount) in amounts.enumerated() {
            let exact = amount / total * 100
            var floored = Decimal()
            var mutable = exact
            NSDecimalRound(&floored, &mutable, 0, .down)
            let floor = (floored as NSDecimalNumber).intValue
            rows.append(Row(index: index, floor: floor, remainder: exact - floored))
        }

        var shares = rows.map(\.floor)
        var remaining = 100 - shares.reduce(0, +)
        let byRemainder = rows.sorted {
            if $0.remainder == $1.remainder { return $0.index < $1.index }
            return $0.remainder > $1.remainder
        }
        var cursor = 0
        while remaining > 0, cursor < byRemainder.count {
            shares[byRemainder[cursor].index] += 1
            remaining -= 1
            cursor += 1
        }
        return shares
    }

    // MARK: - Internals

    public nonisolated static func primaryCurrency(
        among expenses: [TransactionEntity],
        preferred: String
    ) -> String {
        guard !expenses.isEmpty else { return preferred }
        if expenses.contains(where: { $0.currencyCode == preferred }) {
            return preferred
        }
        var counts: [String: Int] = [:]
        for expense in expenses {
            counts[expense.currencyCode, default: 0] += 1
        }
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        }?.key ?? preferred
    }

    public nonisolated static func longestStreakDays(
        in transactions: [TransactionEntity],
        calendar: Calendar
    ) -> Int {
        let days = Set(transactions.map { calendar.startOfDay(for: $0.date) })
            .sorted()
        guard let first = days.first else { return 0 }

        var best = 1
        var current = 1
        var previous = first
        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = day
        }
        return best
    }

    private nonisolated static func monthlyPoints(
        expenses: [TransactionEntity],
        year: Int,
        calendar: Calendar
    ) -> [YearInReviewMonthlyPoint] {
        var totals: [DateComponents: Decimal] = [:]
        for expense in expenses {
            let comps = calendar.dateComponents([.year, .month], from: expense.date)
            totals[comps, default: 0] += expense.amount
        }
        return (1...12).compactMap { month -> YearInReviewMonthlyPoint? in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let start = calendar.date(from: comps) else { return nil }
            let key = calendar.dateComponents([.year, .month], from: start)
            return YearInReviewMonthlyPoint(monthStart: start, amount: totals[key] ?? 0)
        }
    }

    private nonisolated static func categoryShares(
        expenses: [TransactionEntity],
        categoryNames: [UUID: String],
        totalSpent: Decimal
    ) -> [YearInReviewCategoryShare] {
        guard totalSpent > 0 else { return [] }

        var byName: [String: Decimal] = [:]
        for expense in expenses {
            let name: String
            if let id = expense.categoryID, let mapped = categoryNames[id] {
                name = mapped
            } else {
                name = String(localized: "Uncategorized")
            }
            byName[name, default: 0] += expense.amount
        }

        let sorted = byName.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        guard !sorted.isEmpty else { return [] }

        let head = Array(sorted.prefix(topCategoryLimit))
        let tail = sorted.dropFirst(topCategoryLimit)
        var rows: [(String, Decimal)] = head.map { ($0.key, $0.value) }
        let otherTotal = tail.reduce(Decimal(0)) { $0 + $1.value }
        if otherTotal > 0 {
            rows.append((String(localized: "Other"), otherTotal))
        }

        let shares = displayedPercentageShares(amounts: rows.map(\.1))
        return zip(rows, shares).map { row, share in
            YearInReviewCategoryShare(name: row.0, amount: row.1, sharePercent: share)
        }
    }

    private nonisolated static func biggestMonthHighlight(
        expenses: [TransactionEntity],
        categoryNames: [UUID: String],
        calendar: Calendar
    ) -> YearInReviewMonthHighlight? {
        var byMonth: [DateComponents: Decimal] = [:]
        var byMonthCategory: [DateComponents: [String: Decimal]] = [:]

        for expense in expenses {
            let key = calendar.dateComponents([.year, .month], from: expense.date)
            byMonth[key, default: 0] += expense.amount
            let name: String
            if let id = expense.categoryID, let mapped = categoryNames[id] {
                name = mapped
            } else {
                name = String(localized: "Uncategorized")
            }
            var cats = byMonthCategory[key] ?? [:]
            cats[name, default: 0] += expense.amount
            byMonthCategory[key] = cats
        }

        guard let winner = byMonth.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                let lMonth = lhs.key.month ?? 0
                let rMonth = rhs.key.month ?? 0
                return lMonth < rMonth
            }
            return lhs.value < rhs.value
        }) else {
            return nil
        }

        guard let monthStart = calendar.date(from: winner.key) else { return nil }
        let top = byMonthCategory[winner.key]?.max(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        })

        return YearInReviewMonthHighlight(
            monthStart: monthStart,
            amount: winner.value,
            topCategoryName: top?.key,
            topCategoryAmount: top?.value ?? 0
        )
    }

    private nonisolated static func payeeShares(
        expenses: [TransactionEntity],
        payeeNames: [UUID: String]
    ) -> [YearInReviewPayeeShare] {
        var byName: [String: Decimal] = [:]
        for expense in expenses {
            guard let id = expense.payeeID, let name = payeeNames[id] else { continue }
            byName[name, default: 0] += expense.amount
        }
        return byName
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(topPayeeLimit)
            .map { YearInReviewPayeeShare(name: $0.key, amount: $0.value) }
    }
}
