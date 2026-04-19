import SwiftUI

struct UpcomingRecurringList: View {
    let rules: [RecurringRuleEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Upcoming"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            if rules.isEmpty {
                Text(String(localized: "No upcoming recurring transactions"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
            } else {
                VStack(spacing: VSpacing.xs) {
                    ForEach(rules) { rule in
                        UpcomingRuleRow(rule: rule)
                        if rule.id != rules.last?.id {
                            Divider()
                                .padding(.leading, VSpacing.xl + VSpacing.md)
                        }
                    }
                }
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
            }
        }
    }
}

private struct UpcomingRuleRow: View {
    let rule: RecurringRuleEntity

    var body: some View {
        HStack(spacing: VSpacing.md) {
            Circle()
                .fill(VColors.primary.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VColors.primary)
                }

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(rule.templateNote ?? String(localized: "Recurring"))
                    .font(VTypography.caption1Bold)
                    .foregroundColor(VColors.textPrimary)
                    .adaptiveLineLimit(1)

                Text(frequencyLabel(rule.frequency))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                Text(formattedAmount(rule.templateAmount))
                    .font(VTypography.amountCaption)
                    .foregroundColor(VColors.textPrimary)

                Text(dueDateLabel(rule.nextDate))
                    .font(VTypography.caption2)
                    .foregroundColor(isDueSoon(rule.nextDate) ? VColors.warning : VColors.textSecondary)
            }
        }
        .padding(.vertical, VSpacing.xs)
    }

    private func frequencyLabel(_ frequency: RecurrenceFrequency) -> String {
        switch frequency {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .biweekly: return String(localized: "Bi-weekly")
        case .monthly: return String(localized: "Monthly")
        case .quarterly: return String(localized: "Quarterly")
        case .yearly: return String(localized: "Yearly")
        case .custom(let days): return String(localized: "Every \(days) days")
        }
    }

    private func dueDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        } else if calendar.isDateInTomorrow(date) {
            return String(localized: "Tomorrow")
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    private func isDueSoon(_ date: Date) -> Bool {
        let threeDays = Date.now.addingTimeInterval(3 * 86400)
        return date <= threeDays
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    UpcomingRecurringList(rules: [])
        .padding()
}
