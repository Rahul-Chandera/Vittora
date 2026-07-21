import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Notification Schedule Policy Tests")
struct NotificationSchedulePolicyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2027,
                month: 1,
                day: day,
                hour: hour
            )
        ) ?? .now
    }

    @Test("quiet hours crossing midnight defer both sides of midnight")
    func crossingMidnightInsideWindow() {
        let policy = NotificationSchedulePreferences(
            quietHoursEnabled: true,
            quietStartMinutes: 22 * 60,
            quietEndMinutes: 7 * 60
        )

        #expect(
            policy.adjustedFireDate(for: date(day: 10, hour: 23), category: .budgetAlert, calendar: calendar)
                == date(day: 11, hour: 7)
        )
        #expect(
            policy.adjustedFireDate(for: date(day: 10, hour: 6), category: .budgetAlert, calendar: calendar)
                == date(day: 10, hour: 7)
        )
    }

    @Test("quiet hours crossing midnight leave both outside directions unchanged")
    func crossingMidnightOutsideWindow() {
        let policy = NotificationSchedulePreferences(
            quietHoursEnabled: true,
            quietStartMinutes: 22 * 60,
            quietEndMinutes: 7 * 60
        )
        let beforeStart = date(day: 10, hour: 21)
        let afterEnd = date(day: 10, hour: 8)

        #expect(
            policy.adjustedFireDate(for: beforeStart, category: .budgetAlert, calendar: calendar)
                == beforeStart
        )
        #expect(
            policy.adjustedFireDate(for: afterEnd, category: .budgetAlert, calendar: calendar)
                == afterEnd
        )
    }
}
