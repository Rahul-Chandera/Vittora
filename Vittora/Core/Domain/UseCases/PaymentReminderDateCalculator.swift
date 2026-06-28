import Foundation

/// Shared fire-date math for one-shot payment reminders (C4/C5).
enum PaymentReminderDateCalculator {
    static let defaultReminderHour = 9
    static let defaultReminderMinute = 0

    /// Returns a local 9:00 reminder `leadDays` before `occurrence`, or the next
    /// 9:00 slot before `occurrence` when the standard lead window has passed.
    static func preNotificationFireDate(
        occurrence: Date,
        leadDays: Int,
        calendar: Calendar,
        from reference: Date
    ) -> Date? {
        guard occurrence > reference else { return nil }

        let occurrenceStart = calendar.startOfDay(for: occurrence)
        guard let leadDay = calendar.date(byAdding: .day, value: -leadDays, to: occurrenceStart),
              let primaryFire = reminderTime(on: leadDay, calendar: calendar),
              primaryFire > reference, primaryFire < occurrence
        else {
            return fallbackFireDate(before: occurrence, calendar: calendar, from: reference)
        }
        return primaryFire
    }

    private static func fallbackFireDate(
        before occurrence: Date,
        calendar: Calendar,
        from reference: Date
    ) -> Date? {
        var day = calendar.startOfDay(for: reference)
        let occurrenceStart = calendar.startOfDay(for: occurrence)
        while day < occurrenceStart {
            if let fire = reminderTime(on: day, calendar: calendar),
               fire > reference, fire < occurrence {
                return fire
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return nil
    }

    private static func reminderTime(on day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = defaultReminderHour
        components.minute = defaultReminderMinute
        components.second = 0
        return calendar.date(from: components)
    }
}
