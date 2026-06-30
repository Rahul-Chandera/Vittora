import Foundation

public struct SavingsAllocationSnapshot: Sendable, Equatable {
    public nonisolated let monthlyRequired: Decimal?
    public nonisolated let projectedCompletionDate: Date?
    public nonisolated let remainingMonths: Int?

    public nonisolated init(
        monthlyRequired: Decimal?,
        projectedCompletionDate: Date?,
        remainingMonths: Int?
    ) {
        self.monthlyRequired = monthlyRequired
        self.projectedCompletionDate = projectedCompletionDate
        self.remainingMonths = remainingMonths
    }
}

public enum SavingsAllocationMath {
    public nonisolated static func snapshot(
        targetAmount: Decimal,
        currentAmount: Decimal,
        targetDate: Date?,
        plannedMonthlyContribution: Decimal? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> SavingsAllocationSnapshot {
        let remaining = max(0, targetAmount - currentAmount)
        guard remaining > 0 else {
            return SavingsAllocationSnapshot(
                monthlyRequired: 0,
                projectedCompletionDate: referenceDate,
                remainingMonths: 0
            )
        }

        if let targetDate {
            guard let months = calendarMonthsUntil(targetDate, from: referenceDate, calendar: calendar) else {
                return SavingsAllocationSnapshot(monthlyRequired: nil, projectedCompletionDate: nil, remainingMonths: nil)
            }
            let monthly = roundCurrency(remaining / Decimal(months))
            return SavingsAllocationSnapshot(
                monthlyRequired: monthly,
                projectedCompletionDate: targetDate,
                remainingMonths: months
            )
        }

        if let planned = plannedMonthlyContribution, planned > 0 {
            let months = monthsRequired(remaining: remaining, monthlyContribution: planned)
            let projected = calendar.date(byAdding: .month, value: months, to: referenceDate)
            return SavingsAllocationSnapshot(
                monthlyRequired: planned,
                projectedCompletionDate: projected,
                remainingMonths: months
            )
        }

        return SavingsAllocationSnapshot(monthlyRequired: nil, projectedCompletionDate: nil, remainingMonths: nil)
    }

    public nonisolated static func monthlyRequired(
        targetAmount: Decimal,
        currentAmount: Decimal,
        targetDate: Date?,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal? {
        snapshot(
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            referenceDate: referenceDate,
            calendar: calendar
        ).monthlyRequired
    }

    public nonisolated static func calendarMonthsUntil(
        _ targetDate: Date,
        from referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: targetDate)
        guard end > start else { return nil }

        let components = calendar.dateComponents([.month, .day], from: start, to: end)
        guard let wholeMonths = components.month else { return nil }
        let partialMonth = (components.day ?? 0) > 0 ? 1 : 0
        return max(1, wholeMonths + partialMonth)
    }

    public nonisolated static func monthsRequired(remaining: Decimal, monthlyContribution: Decimal) -> Int {
        guard remaining > 0, monthlyContribution > 0 else { return 0 }
        var quotient = remaining / monthlyContribution
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .up)
        return max(1, (rounded as NSDecimalNumber).intValue)
    }

    public nonisolated static func roundCurrency(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .bankers)
        return result
    }
}
