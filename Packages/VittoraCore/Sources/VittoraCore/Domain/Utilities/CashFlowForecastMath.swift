import Foundation

/// One day of a cash-flow balance forecast (plan M2.8.5 / R3).
public struct CashFlowForecastPoint: Sendable, Equatable, Identifiable {
    public nonisolated var id: Date { date }
    /// Calendar day this balance applies to (start of day).
    public nonisolated let date: Date
    /// Days after `today` (0 = today / starting balance).
    public nonisolated let dayOffset: Int
    /// Projected balance at end of this day.
    public nonisolated let balance: Decimal
    /// Net change applied on this day (0 on day 0).
    public nonisolated let delta: Decimal

    public nonisolated init(date: Date, dayOffset: Int, balance: Decimal, delta: Decimal) {
        self.date = date
        self.dayOffset = dayOffset
        self.balance = balance
        self.delta = delta
    }
}

public struct CashFlowForecastResult: Sendable, Equatable {
    public nonisolated let points: [CashFlowForecastPoint]
    public nonisolated let averageDailyDiscretionarySpend: Decimal
    public nonisolated let startingBalance: Decimal
    public nonisolated let historyDayCount: Int
    public nonisolated let discretionaryExpenseTotal: Decimal

    public nonisolated init(
        points: [CashFlowForecastPoint],
        averageDailyDiscretionarySpend: Decimal,
        startingBalance: Decimal,
        historyDayCount: Int,
        discretionaryExpenseTotal: Decimal
    ) {
        self.points = points
        self.averageDailyDiscretionarySpend = averageDailyDiscretionarySpend
        self.startingBalance = startingBalance
        self.historyDayCount = historyDayCount
        self.discretionaryExpenseTotal = discretionaryExpenseTotal
    }

    /// Balance at end of day `offset` (1...dayCount). Nil when out of range.
    public nonisolated func balance(atDayOffset offset: Int) -> Decimal? {
        points.first { $0.dayOffset == offset }?.balance
    }
}

/// Signed cash movement on a calendar day (income positive, expense negative).
public struct CashFlowForecastScheduledDelta: Sendable, Equatable {
    public nonisolated let day: Date
    public nonisolated let amount: Decimal

    public nonisolated init(day: Date, amount: Decimal) {
        self.day = day
        self.amount = amount
    }
}

/// Pure, deterministic 90-day cash-flow forecast math.
///
/// Callers inject `today` — never reads `Date.now`. Displayed balances are built
/// by summing the same daily deltas that are charted (no inverse round-trips).
public enum CashFlowForecastMath {
    public static let defaultDayCount = 90
    public static let defaultTrailingHistoryDays = 90

    /// Average daily discretionary spend = non-recurring expense total ÷ days.
    /// Returns 0 when `historyDayCount` is 0 (no divide-by-zero).
    public nonisolated static func averageDailyDiscretionarySpend(
        nonRecurringExpenseTotal: Decimal,
        historyDayCount: Int
    ) -> Decimal {
        guard historyDayCount > 0 else { return 0 }
        return nonRecurringExpenseTotal / Decimal(historyDayCount)
    }

    /// Calendar-day count of the available history window ending at `todayStart`.
    ///
    /// Uses the trailing lookback capped by the earliest transaction day when the
    /// user has less than `trailingHistoryDays` of data. Zero transactions → 0.
    public nonisolated static func historyDayCount(
        todayStart: Date,
        earliestTransactionDay: Date?,
        trailingHistoryDays: Int = defaultTrailingHistoryDays,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        guard let earliestTransactionDay else { return 0 }
        guard let lookbackStart = calendar.date(
            byAdding: .day,
            value: -trailingHistoryDays,
            to: todayStart
        ) else {
            return 0
        }
        let availableStart = max(lookbackStart, calendar.startOfDay(for: earliestTransactionDay))
        let days = calendar.dateComponents([.day], from: availableStart, to: todayStart).day ?? 0
        return max(0, days)
    }

    /// Start of the available history window used for discretionary totaling.
    public nonisolated static func historyWindowStart(
        todayStart: Date,
        earliestTransactionDay: Date?,
        trailingHistoryDays: Int = defaultTrailingHistoryDays,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard historyDayCount(
            todayStart: todayStart,
            earliestTransactionDay: earliestTransactionDay,
            trailingHistoryDays: trailingHistoryDays,
            calendar: calendar
        ) > 0 else {
            return nil
        }
        guard let lookbackStart = calendar.date(
            byAdding: .day,
            value: -trailingHistoryDays,
            to: todayStart
        ), let earliestTransactionDay else {
            return nil
        }
        return max(lookbackStart, calendar.startOfDay(for: earliestTransactionDay))
    }

    /// Projects balance forward `dayCount` days from `todayStart`.
    ///
    /// - Day 0: starting balance (no delta).
    /// - Days 1...dayCount: each day applies scheduled recurring net for that
    ///   calendar day minus the average daily discretionary spend.
    public nonisolated static func project(
        startingBalance: Decimal,
        averageDailyDiscretionarySpend: Decimal,
        scheduledDeltas: [CashFlowForecastScheduledDelta],
        todayStart: Date,
        dayCount: Int = defaultDayCount,
        historyDayCount: Int = 0,
        discretionaryExpenseTotal: Decimal = 0,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CashFlowForecastResult {
        var deltasByDay: [Date: Decimal] = [:]
        for item in scheduledDeltas {
            let day = calendar.startOfDay(for: item.day)
            deltasByDay[day, default: 0] += item.amount
        }

        var points: [CashFlowForecastPoint] = [
            CashFlowForecastPoint(
                date: todayStart,
                dayOffset: 0,
                balance: startingBalance,
                delta: 0
            )
        ]

        var balance = startingBalance
        for offset in 1...max(0, dayCount) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: todayStart) else {
                continue
            }
            let day = calendar.startOfDay(for: date)
            let recurringNet = deltasByDay[day] ?? 0
            // Discretionary is a spend → subtract. Do not derive this from another
            // displayed total; each day uses the same per-day average input.
            let delta = recurringNet - averageDailyDiscretionarySpend
            balance += delta
            points.append(
                CashFlowForecastPoint(
                    date: day,
                    dayOffset: offset,
                    balance: balance,
                    delta: delta
                )
            )
        }

        return CashFlowForecastResult(
            points: points,
            averageDailyDiscretionarySpend: averageDailyDiscretionarySpend,
            startingBalance: startingBalance,
            historyDayCount: historyDayCount,
            discretionaryExpenseTotal: discretionaryExpenseTotal
        )
    }
}
