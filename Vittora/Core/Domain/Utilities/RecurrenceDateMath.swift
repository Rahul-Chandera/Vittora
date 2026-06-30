import Foundation
import VittoraCore

/// Deterministic recurrence date stepping (shared by cash-flow projection and generation).
enum RecurrenceDateMath {
    nonisolated static func nextOccurrence(
        after date: Date,
        frequency: RecurrenceFrequency,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date.addingTimeInterval(604800)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date.addingTimeInterval(1_209_600)
        case .monthly:
            return addMonths(1, to: date, calendar: calendar)
        case .quarterly:
            return addMonths(3, to: date, calendar: calendar)
        case .yearly:
            return addMonths(12, to: date, calendar: calendar)
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: date)
                ?? date.addingTimeInterval(TimeInterval(days * 86_400))
        }
    }

    nonisolated static func occurrences(
        startingAt startDate: Date,
        frequency: RecurrenceFrequency,
        in interval: Range<Date>,
        endDate: Date?,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [Date] {
        var results: [Date] = []
        var occurrence = startDate

        while occurrence < interval.lowerBound {
            let next = nextOccurrence(after: occurrence, frequency: frequency, calendar: calendar)
            guard next > occurrence else { break }
            occurrence = next
        }

        while occurrence < interval.upperBound {
            guard isWithinEndDate(occurrence, endDate: endDate) else { break }
            results.append(occurrence)
            let next = nextOccurrence(after: occurrence, frequency: frequency, calendar: calendar)
            guard next > occurrence else { break }
            occurrence = next
        }

        return results
    }

    nonisolated static func totalAmount(
        for rules: [RecurringRuleEntity],
        in interval: Range<Date>,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Decimal {
        rules.reduce(into: Decimal(0)) { total, rule in
            guard rule.isActive, rule.templateAccountID != nil else { return }
            let dates = occurrences(
                startingAt: rule.nextDate,
                frequency: rule.frequency,
                in: interval,
                endDate: rule.endDate,
                calendar: calendar
            )
            total += Decimal(dates.count) * rule.templateAmount
        }
    }

    nonisolated private static func isWithinEndDate(_ occurrence: Date, endDate: Date?) -> Bool {
        guard let endDate else { return true }
        return occurrence <= endDate
    }

    nonisolated private static func addMonths(_ months: Int, to date: Date, calendar: Calendar) -> Date {
        let fallback = calendar.date(byAdding: .month, value: months, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard let day = components.day,
              let monthRange = calendar.range(of: .day, in: .month, for: date) else {
            return fallback
        }
        let isLastDayOfMonth = day == monthRange.count

        var firstOfMonth = DateComponents()
        firstOfMonth.year = components.year
        firstOfMonth.month = components.month
        firstOfMonth.day = 1
        firstOfMonth.hour = components.hour
        firstOfMonth.minute = components.minute
        firstOfMonth.second = components.second

        guard let baseDate = calendar.date(from: firstOfMonth),
              let targetMonthDate = calendar.date(byAdding: .month, value: months, to: baseDate),
              let targetRange = calendar.range(of: .day, in: .month, for: targetMonthDate) else {
            return fallback
        }

        let targetDay = isLastDayOfMonth ? targetRange.count : min(day, targetRange.count)
        var result = calendar.dateComponents([.year, .month, .hour, .minute, .second], from: targetMonthDate)
        result.day = targetDay
        return calendar.date(from: result) ?? fallback
    }
}
