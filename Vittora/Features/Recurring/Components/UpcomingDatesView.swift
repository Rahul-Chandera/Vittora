import SwiftUI

struct UpcomingDatesView: View {
    let rule: RecurringRuleEntity
    let count: Int = 5

    private var upcomingDates: [Date] {
        var dates: [Date] = []
        var currentDate = rule.nextDate
        let calendar = Calendar.current

        for _ in 0..<count {
            if let endDate = rule.endDate, currentDate > endDate {
                break
            }
            dates.append(currentDate)
            currentDate = advanceDate(from: currentDate, frequency: rule.frequency)
        }

        return dates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Upcoming Dates")
                .font(VTypography.calloutBold)
                .foregroundColor(VColors.textPrimary)

            VStack(spacing: VSpacing.sm) {
                ForEach(upcomingDates, id: \.self) { date in
                    HStack(spacing: VSpacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(VColors.primary)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: VSpacing.xxs) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(VTypography.callout)
                                .foregroundColor(VColors.textPrimary)

                            Text(date.formatted(date: .omitted, time: .standard))
                                .font(VTypography.caption2)
                                .foregroundColor(VColors.textSecondary)
                        }

                        Spacer()

                        Text(daysFromNow(date))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                            .padding(.horizontal, VSpacing.sm)
                            .padding(.vertical, VSpacing.xs)
                            .background(VColors.tertiaryBackground)
                            .cornerRadius(VSpacing.cornerRadiusSM)
                    }
                    .padding(VSpacing.md)
                    .background(VColors.secondaryBackground)
                    .cornerRadius(VSpacing.cornerRadiusMD)
                }
            }
        }
    }

    private func advanceDate(from date: Date, frequency: RecurrenceFrequency) -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date.addingTimeInterval(604800)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date.addingTimeInterval(1209600)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date.addingTimeInterval(2592000)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date.addingTimeInterval(7776000)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date.addingTimeInterval(31536000)
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days * 86400))
        }
    }

    private func daysFromNow(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days > 0 {
            return "In \(days)d"
        } else {
            return "Overdue"
        }
    }
}

#Preview {
    let sampleRule = RecurringRuleEntity(
        frequency: .monthly,
        nextDate: Date.now.addingTimeInterval(86400),
        templateAmount: 29.99
    )

    VStack(spacing: VSpacing.lg) {
        UpcomingDatesView(rule: sampleRule)
            .padding(VSpacing.lg)

        Spacer()
    }
    .background(VColors.background)
}
