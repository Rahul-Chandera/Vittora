import Foundation
import VittoraCore

/// Computes credit-card due dates and pre-due reminder fire times (C4).
enum CreditCardDueDateCalculator {
    nonisolated static let validDayRange = 1...31
    nonisolated static let defaultLeadDays = 3
    nonisolated static let defaultReminderHour = 9
    nonisolated static let defaultReminderMinute = 0

    nonisolated static func isValidDayOfMonth(_ day: Int) -> Bool {
        validDayRange.contains(day)
    }

    /// Due date for `dayOfMonth` in the month containing `monthAnchor`, clamped to the month's length.
    nonisolated static func dueDate(
        dayOfMonth: Int,
        monthAnchor: Date,
        calendar: Calendar
    ) -> Date? {
        guard isValidDayOfMonth(dayOfMonth) else { return nil }
        var monthComponents = calendar.dateComponents([.year, .month], from: monthAnchor)
        guard let monthStart = calendar.date(from: monthComponents) else { return nil }
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? dayOfMonth
        monthComponents.day = min(dayOfMonth, daysInMonth)
        monthComponents.hour = 0
        monthComponents.minute = 0
        monthComponents.second = 0
        return calendar.date(from: monthComponents)
    }

    /// Next upcoming reminder (due date minus lead days at 9:00 local).
    nonisolated static func nextReminderDate(
        dayOfMonth: Int,
        leadDays: Int = defaultLeadDays,
        calendar: Calendar,
        from reference: Date
    ) -> Date? {
        guard let thisMonthDue = dueDate(dayOfMonth: dayOfMonth, monthAnchor: reference, calendar: calendar),
              let rawReminder = calendar.date(byAdding: .day, value: -leadDays, to: thisMonthDue)
        else {
            return nil
        }

        let thisMonthFire = startOfReminderDay(rawReminder, calendar: calendar)
        if let thisMonthFire, thisMonthFire > reference {
            return thisMonthFire
        }

        guard let nextMonthAnchor = calendar.date(byAdding: .month, value: 1, to: thisMonthDue),
              let nextDue = dueDate(dayOfMonth: dayOfMonth, monthAnchor: nextMonthAnchor, calendar: calendar),
              let nextRawReminder = calendar.date(byAdding: .day, value: -leadDays, to: nextDue),
              let nextMonthFire = startOfReminderDay(nextRawReminder, calendar: calendar)
        else {
            return nil
        }
        return nextMonthFire
    }

    nonisolated private static func startOfReminderDay(_ date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = defaultReminderHour
        components.minute = defaultReminderMinute
        components.second = 0
        return calendar.date(from: components)
    }
}
