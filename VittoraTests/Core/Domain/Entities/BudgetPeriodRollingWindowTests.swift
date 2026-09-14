import Foundation
import Testing
import VittoraCore

@Suite("BudgetPeriod rolling window")
struct BudgetPeriodRollingWindowTests {

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) throws -> Date {
        try #require(
            Calendar.current.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    @Test("monthly window several periods in the past still contains today")
    func monthlyWindowSeveralPeriodsInThePastStillContainsToday() throws {
        let startDate = try date(2024, 3, 15, hour: 12)
        let asOf = try date(2024, 9, 20, hour: 12)
        let expectedLower = try date(2024, 9, 15, hour: 12)
        let expectedUpper = try date(2024, 10, 15, hour: 12)

        let range = BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
        #expect(range.upperBound == expectedUpper)
    }

    @Test("a budget started years ago rolls all the way forward")
    func budgetStartedYearsAgoRollsAllTheWayForward() throws {
        let startDate = try date(2019, 1, 10)
        let asOf = try date(2026, 9, 12)
        let expectedLower = try date(2026, 9, 10)

        let range = BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.contains(asOf))
        #expect(range.lowerBound == expectedLower)
    }

    @Test("consecutive monthly windows leave no gap when the start day does not exist in every month")
    func consecutiveMonthlyWindowsLeaveNoGapWhenStartDayMissing() throws {
        let startDate = try date(2024, 1, 31)
        let asOfDates = [
            try date(2024, 2, 15),
            try date(2024, 2, 29),
            try date(2024, 3, 1),
            try date(2024, 3, 30),
            try date(2024, 4, 20),
            try date(2024, 5, 31),
        ]

        for asOf in asOfDates {
            let range = BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)
            #expect(range.contains(asOf))
        }
    }

    @Test("weekly window rolls forward in whole weeks")
    func weeklyWindowRollsForwardInWholeWeeks() throws {
        let startDate = try date(2024, 1, 1)
        let asOf = try date(2024, 2, 8)
        let expectedLower = try date(2024, 2, 5)
        let expectedUpper = try date(2024, 2, 12)

        let range = BudgetPeriod.weekly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
        #expect(range.upperBound == expectedUpper)
    }

    @Test("quarterly window rolls forward in whole quarters")
    func quarterlyWindowRollsForwardInWholeQuarters() throws {
        let startDate = try date(2024, 1, 15)
        let asOf = try date(2024, 11, 1)
        let expectedLower = try date(2024, 10, 15)
        let expectedUpper = try date(2025, 1, 15)

        let range = BudgetPeriod.quarterly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
        #expect(range.upperBound == expectedUpper)
    }

    @Test("yearly window rolls forward in whole years")
    func yearlyWindowRollsForwardInWholeYears() throws {
        let startDate = try date(2020, 6, 1)
        let asOf = try date(2026, 2, 2)
        let expectedLower = try date(2025, 6, 1)
        let expectedUpper = try date(2026, 6, 1)

        let range = BudgetPeriod.yearly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
        #expect(range.upperBound == expectedUpper)
    }

    @Test("a date before the start date returns the first window")
    func dateBeforeStartDateReturnsFirstWindow() throws {
        let startDate = try date(2026, 1, 1)
        let asOf = try date(2025, 12, 1)
        let expectedLower = try date(2026, 1, 1)
        let expectedUpper = try date(2026, 2, 1)

        let range = BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
        #expect(range.upperBound == expectedUpper)
    }

    @Test("exactly on a window boundary begins the next window")
    func exactlyOnWindowBoundaryBeginsNextWindow() throws {
        let startDate = try date(2024, 1, 1)
        let asOf = try date(2024, 2, 1)
        let expectedLower = try date(2024, 2, 1)

        let range = BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)

        #expect(range.lowerBound == expectedLower)
    }

    @Test("BudgetEntity.currentDateRange delegates to its own period and startDate")
    func budgetEntityCurrentDateRangeDelegates() throws {
        let startDate = try date(2024, 3, 15)
        let asOf = try date(2024, 9, 20)
        let entity = BudgetEntity(amount: 3400, period: .monthly, startDate: startDate)

        #expect(
            entity.currentDateRange(asOf: asOf)
                == BudgetPeriod.monthly.currentDateRange(startingFrom: startDate, asOf: asOf)
        )
    }
}
