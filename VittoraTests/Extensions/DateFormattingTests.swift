import Foundation
import Testing
@testable import Vittora

@Suite("Date Formatting Tests")
struct DateFormattingTests {
    private let calendar = Calendar.current

    // Helper to call our custom extension without ambiguity
    private func format(_ date: Date, as style: Date.DateFormatStyle) -> String {
        date.formatted(as: style)
    }

    // Helper to create dates for testing
    private func dateByAdding(days: Int, to date: Date = Date()) -> Date {
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    @Test("Format date as short style")
    func testFormatShort() {
        let date = Date()
        let formatted = format(date, as: .short)
        #expect(!formatted.isEmpty)
        #expect(formatted.count >= 8) // MM/dd/yy format
    }

    @Test("Format date as medium style")
    func testFormatMedium() {
        let date = Date()
        let formatted = format(date, as: .medium)
        #expect(!formatted.isEmpty)
        // Should contain day, month, and year
    }

    @Test("Format date as long style")
    func testFormatLong() {
        let date = Date()
        let formatted = format(date, as: .long)
        #expect(!formatted.isEmpty)
    }

    @Test("Format date as month-year style")
    func testFormatMonthYear() {
        let date = Date()
        let formatted = format(date, as: .monthYear)
        #expect(!formatted.isEmpty)
    }

    @Test("Format date as year only")
    func testFormatYearOnly() {
        let date = Date()
        let formatted = format(date, as: .yearOnly)
        #expect(formatted.count == 4) // Should be just the year
    }

    @Test("Format date as time")
    func testFormatTime() {
        let date = Date()
        let formatted = format(date, as: .time)
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":")) // Should have time separator
    }

    @Test("Format relative - just now")
    func testFormatRelativeNow() {
        let date = Date()
        let formatted = format(date, as: .relative)
        #expect(!formatted.isEmpty)
    }

    @Test("Format relative - hours ago")
    func testFormatRelativeHoursAgo() {
        let threeHoursAgo = calendar.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
        let formatted = format(threeHoursAgo, as: .relative)
        #expect(formatted.contains("ago") || formatted.contains("hour"))
    }

    @Test("Format relative - days ago")
    func testFormatRelativeDaysAgo() {
        let fiveDaysAgo = dateByAdding(days: -5)
        let formatted = format(fiveDaysAgo, as: .relative)
        #expect(formatted.contains("ago") || formatted.contains("day"))
    }

    @Test("Format relative - yesterday")
    func testFormatRelativeYesterday() {
        let yesterday = dateByAdding(days: -1)
        let formatted = format(yesterday, as: .relative)
        #expect(formatted.contains("ago") || formatted.contains("Yesterday") || formatted.lowercased().contains("yesterday"))
    }

    @Test("Is today property")
    func testIsToday() {
        let date = Date()
        #expect(date.isToday == true)
    }

    @Test("Is today property - yesterday")
    func testIsTodayYesterday() {
        let yesterday = dateByAdding(days: -1)
        #expect(yesterday.isToday == false)
    }

    @Test("Is yesterday property")
    func testIsYesterday() {
        let yesterday = dateByAdding(days: -1)
        #expect(yesterday.isYesterday == true)
    }

    @Test("Is tomorrow property")
    func testIsTomorrow() {
        let tomorrow = dateByAdding(days: 1)
        #expect(tomorrow.isTomorrow == true)
    }

    @Test("Is past property")
    func testIsPast() {
        let pastDate = dateByAdding(days: -10)
        #expect(pastDate.isPast == true)
    }

    @Test("Is future property")
    func testIsFuture() {
        let futureDate = dateByAdding(days: 10)
        #expect(futureDate.isFuture == true)
    }

    @Test("Start of day")
    func testStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("End of day")
    func testEndOfDay() {
        let date = Date()
        let endOfDay = date.endOfDay
        let components = calendar.dateComponents([.day], from: endOfDay)
        let startOfDayComponents = calendar.dateComponents([.day], from: date.startOfDay)
        #expect(components.day == startOfDayComponents.day)
    }

    @Test("Start of month")
    func testStartOfMonth() {
        let date = Date()
        let startOfMonth = date.startOfMonth
        let components = calendar.dateComponents([.day], from: startOfMonth)
        #expect(components.day == 1)
    }

    @Test("End of month")
    func testEndOfMonth() {
        let date = Date()
        let endOfMonth = date.endOfMonth
        let nextDay = calendar.date(byAdding: .day, value: 1, to: endOfMonth) ?? Date()
        let startOfNextMonth = nextDay.startOfMonth
        #expect(endOfMonth < startOfNextMonth)
    }

    @Test("Start of year")
    func testStartOfYear() {
        let date = Date()
        let startOfYear = date.startOfYear
        let components = calendar.dateComponents([.month, .day], from: startOfYear)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @Test("End of year")
    func testEndOfYear() {
        let date = Date()
        let endOfYear = date.endOfYear
        let components = calendar.dateComponents([.month, .day], from: endOfYear)
        #expect(components.month == 12)
        #expect(components.day == 31)
    }

    @Test("Days between dates")
    func testDaysBetween() {
        let date1 = Date()
        let date2 = dateByAdding(days: 5)
        let daysBetween = date1.daysBetween(date2)
        #expect(daysBetween == 5)
    }

    @Test("Is in same week")
    func testIsInSameWeek() {
        let date = Date()
        let nextDay = dateByAdding(days: 1)
        #expect(date.isInSameWeek(as: nextDay) == true)
    }

    @Test("Is in same month")
    func testIsInSameMonth() {
        let date = Date()
        let nextDay = dateByAdding(days: 5)
        #expect(date.isInSameMonth(as: nextDay) == true)
    }

    @Test("Is in same year")
    func testIsInSameYear() {
        let date = Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        #expect(date.isInSameYear(as: nextMonth) == true)
    }

    @Test("Custom format style")
    func testCustomFormatStyle() {
        let date = Date()
        let formatted = format(date, as: .custom("dd/MM/yyyy"))
        #expect(!formatted.isEmpty)
        #expect(formatted.count >= 8) // dd/MM/yyyy format
    }
}
