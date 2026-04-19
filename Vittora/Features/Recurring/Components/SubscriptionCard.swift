import SwiftUI

struct SubscriptionCard: View {
    let rule: RecurringRuleEntity
    let monthlyCost: Decimal
    var category: CategoryEntity? = nil
    var currencyCode: String = "USD"

    private var categoryColor: Color {
        if let colorHex = category?.colorHex {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }

    private var categoryIcon: String {
        category?.icon ?? "tag.fill"
    }

    private var frequencyLabel: String {
        switch rule.frequency {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        case .custom(let days):
            return "Every \(days) days"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            // Header
            HStack(spacing: VSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor)
                        .opacity(0.15)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                .frame(width: 44, height: 44)

                // Title and Frequency
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(category?.name ?? "Uncategorized")
                        .font(VTypography.calloutBold)
                        .foregroundColor(VColors.textPrimary)

                    Text(frequencyLabel)
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                }

                Spacer()

                // Status
                Image(systemName: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundColor(rule.isActive ? .green : .orange)
                    .font(.system(size: 18))
            }

            // Divider
            Divider()

            // Cost breakdown
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(String(localized: "Per Transaction"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)

                    Text(String(format: "$%.2f", Double(truncating: rule.templateAmount as NSDecimalNumber)))
                        .font(VTypography.title3)
                        .foregroundColor(VColors.expense)
                }

                Spacer()

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(String(localized: "Monthly Cost"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)

                    Text(String(format: "$%.2f", Double(truncating: monthlyCost as NSDecimalNumber)))
                        .font(VTypography.title3)
                        .foregroundColor(VColors.expense)
                }
            }

            // Next date
            HStack(spacing: VSpacing.md) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VColors.textSecondary)

                Text(String(localized: "Next: \(rule.nextDate.formatted(date: .abbreviated, time: .omitted))"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)

                Spacer()
            }
        }
        .padding(VSpacing.lg)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                .stroke(
                    rule.isActive ? Color.clear : Color.orange.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    let sampleRule = RecurringRuleEntity(
        frequency: .monthly,
        nextDate: Date.now,
        isActive: true,
        templateAmount: Decimal(string: "29.99") ?? 29.99
    )
    let sampleCategory = CategoryEntity(
        name: "Subscriptions",
        icon: "star.fill",
        colorHex: "#FF9500",
        type: .expense
    )

    VStack(spacing: VSpacing.lg) {
        SubscriptionCard(
            rule: sampleRule,
            monthlyCost: Decimal(string: "29.99") ?? 29.99,
            category: sampleCategory
        )
        .padding(VSpacing.lg)

        Spacer()
    }
    .background(VColors.background)
}
