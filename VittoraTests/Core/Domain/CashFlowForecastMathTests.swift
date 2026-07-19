import Foundation
import Testing
import VittoraCore

@Suite("Cash Flow Forecast Math Tests")
struct CashFlowForecastMathTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }

    private var today: Date {
        date(2026, 7, 19)
    }

    // MARK: - Average / history window

    @Test("zero history yields zero average (no divide-by-zero)")
    func zeroHistoryAverage() {
        let average = CashFlowForecastMath.averageDailyDiscretionarySpend(
            nonRecurringExpenseTotal: 100,
            historyDayCount: 0
        )
        #expect(average == 0)
        #expect(
            CashFlowForecastMath.historyDayCount(
                todayStart: today,
                earliestTransactionDay: nil,
                calendar: calendar
            ) == 0
        )
    }

    @Test("history shorter than 90 days uses available window, not 90")
    func shortHistoryUsesAvailableWindow() {
        let earliest = date(2026, 6, 19) // 30 days before today
        let days = CashFlowForecastMath.historyDayCount(
            todayStart: today,
            earliestTransactionDay: earliest,
            calendar: calendar
        )
        #expect(days == 30)

        let total = Decimal(string: "300")!
        let average = CashFlowForecastMath.averageDailyDiscretionarySpend(
            nonRecurringExpenseTotal: total,
            historyDayCount: days
        )
        #expect(average == Decimal(string: "10")!)
    }

    @Test("full trailing window caps at 90 days")
    func fullTrailingWindowCapsAt90() {
        let earliest = date(2025, 1, 1)
        let days = CashFlowForecastMath.historyDayCount(
            todayStart: today,
            earliestTransactionDay: earliest,
            calendar: calendar
        )
        #expect(days == 90)
    }

    // MARK: - Projection edge cases

    @Test("no recurring rules: balance declines by discretionary only")
    func noRecurringRules() {
        let average = Decimal(string: "10")!
        let result = CashFlowForecastMath.project(
            startingBalance: 1_000,
            averageDailyDiscretionarySpend: average,
            scheduledDeltas: [],
            todayStart: today,
            dayCount: 90,
            historyDayCount: 90,
            discretionaryExpenseTotal: 900,
            calendar: calendar
        )

        #expect(result.points.count == 91) // day 0 + 90
        #expect(result.balance(atDayOffset: 30) == Decimal(700)) // 1000 - 10*30
        #expect(result.balance(atDayOffset: 90) == Decimal(100)) // 1000 - 10*90
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    @Test("only income recurring: income offsets discretionary")
    func onlyIncome() {
        // +100 on day 10; discretionary 5/day
        let incomeDay = date(2026, 7, 29) // today + 10
        let result = CashFlowForecastMath.project(
            startingBalance: 500,
            averageDailyDiscretionarySpend: 5,
            scheduledDeltas: [
                CashFlowForecastScheduledDelta(day: incomeDay, amount: 100)
            ],
            todayStart: today,
            dayCount: 30,
            calendar: calendar
        )

        // Days 1-9: -5 each → 500 - 45 = 455 at day 9
        // Day 10: +100 - 5 = +95 → 550
        // Days 11-30: -5 × 20 = -100 → 450
        #expect(result.balance(atDayOffset: 9) == Decimal(455))
        #expect(result.balance(atDayOffset: 10) == Decimal(550))
        #expect(result.balance(atDayOffset: 30) == Decimal(450))
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    @Test("only expense recurring: expenses stack with discretionary")
    func onlyExpenses() {
        let expenseDay = date(2026, 7, 24) // today + 5
        let result = CashFlowForecastMath.project(
            startingBalance: 1_000,
            averageDailyDiscretionarySpend: 10,
            scheduledDeltas: [
                CashFlowForecastScheduledDelta(day: expenseDay, amount: -50)
            ],
            todayStart: today,
            dayCount: 10,
            calendar: calendar
        )

        // Day 5: -50 - 10; days 1-10 otherwise -10
        // 1000 - 10*10 - 50 = 850
        #expect(result.balance(atDayOffset: 10) == Decimal(850))
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    @Test("rule ending mid-window stops contributing after endDate day")
    func ruleEndingMidWindow() {
        // Model as scheduled deltas only on days still within the rule.
        // Daily -20 on days 1...15 only (ended mid-window).
        let deltas = (1...15).compactMap { offset -> CashFlowForecastScheduledDelta? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return CashFlowForecastScheduledDelta(day: day, amount: -20)
        }

        let result = CashFlowForecastMath.project(
            startingBalance: 1_000,
            averageDailyDiscretionarySpend: 0,
            scheduledDeltas: deltas,
            todayStart: today,
            dayCount: 30,
            calendar: calendar
        )

        #expect(result.balance(atDayOffset: 15) == Decimal(700))
        #expect(result.balance(atDayOffset: 30) == Decimal(700)) // flat after end
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    @Test("zero-history user: flat line from recurring only")
    func zeroHistoryFlatFromRecurringOnly() {
        let payday = date(2026, 7, 25) // +6
        let result = CashFlowForecastMath.project(
            startingBalance: 2_000,
            averageDailyDiscretionarySpend: 0,
            scheduledDeltas: [
                CashFlowForecastScheduledDelta(day: payday, amount: 500)
            ],
            todayStart: today,
            dayCount: 10,
            historyDayCount: 0,
            discretionaryExpenseTotal: 0,
            calendar: calendar
        )

        #expect(result.averageDailyDiscretionarySpend == 0)
        #expect(result.balance(atDayOffset: 5) == Decimal(2_000))
        #expect(result.balance(atDayOffset: 6) == Decimal(2_500))
        #expect(result.balance(atDayOffset: 10) == Decimal(2_500))
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    @Test("day-30 balance equals starting + sum of first 30 deltas (no inverse arithmetic)")
    func day30ReconcilesFromDeltas() {
        let average = Decimal(string: "12.50")!
        let rentDay = date(2026, 8, 1) // +13
        let result = CashFlowForecastMath.project(
            startingBalance: Decimal(string: "4450")!,
            averageDailyDiscretionarySpend: average,
            scheduledDeltas: [
                CashFlowForecastScheduledDelta(day: rentDay, amount: Decimal(string: "-1850")!),
                CashFlowForecastScheduledDelta(day: date(2026, 7, 25), amount: Decimal(string: "6400")!)
            ],
            todayStart: today,
            dayCount: 90,
            calendar: calendar
        )

        let day30Deltas = result.points.filter { $0.dayOffset >= 1 && $0.dayOffset <= 30 }
        let summed = day30Deltas.reduce(Decimal(0)) { $0 + $1.delta }
        #expect(result.balance(atDayOffset: 30) == result.startingBalance + summed)
        assertRunningBalanceEqualsSumOfDeltas(result)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    private func assertRunningBalanceEqualsSumOfDeltas(_ result: CashFlowForecastResult) {
        var running = result.startingBalance
        for point in result.points {
            if point.dayOffset == 0 {
                #expect(point.balance == result.startingBalance)
                #expect(point.delta == 0)
            } else {
                running += point.delta
                #expect(point.balance == running)
            }
        }
    }
}
