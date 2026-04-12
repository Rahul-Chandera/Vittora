import SwiftUI

struct RecurringRowView: View {
    let rule: RecurringRuleEntity
    var category: CategoryEntity? = nil

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
            return "Every \(days)d"
        }
    }

    private var categoryColor: Color {
        if let colorHex = category?.colorHex {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }

    private var categoryIcon: String {
        category?.icon ?? "tag.fill"
    }

    var body: some View {
        HStack(spacing: VSpacing.md) {
            // Category icon circle
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .opacity(0.15)

                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryColor)
            }
            .frame(width: 44, height: 44)

            // Content
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                HStack {
                    Text(category?.name ?? "Uncategorized")
                        .font(VTypography.calloutBold)
                        .foregroundColor(VColors.textPrimary)

                    Spacer()

                    // Amount with bold styling
                    Text(String(format: "$%.2f", Double(truncating: rule.templateAmount as NSDecimalNumber)))
                        .font(VTypography.calloutBold)
                        .foregroundColor(VColors.expense)
                }

                HStack {
                    Text(frequencyLabel)
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                        .padding(.horizontal, VSpacing.sm)
                        .padding(.vertical, VSpacing.xs)
                        .background(VColors.tertiaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusSM)

                    Spacer()

                    // Next date
                    Text(rule.nextDate.formatted(date: .abbreviated, time: .omitted))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                }
            }

            Spacer()

            // Status indicator
            VStack(spacing: VSpacing.xxs) {
                Image(systemName: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundColor(rule.isActive ? .green : .orange)
                    .font(.system(size: 20))
            }
        }
        .padding(VSpacing.md)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }
}

#Preview {
    let sampleRule = RecurringRuleEntity(
        frequency: .monthly,
        nextDate: Date.now,
        templateAmount: Decimal(string: "29.99") ?? 29.99
    )
    let sampleCategory = CategoryEntity(
        name: "Subscriptions",
        icon: "star.fill",
        colorHex: "#FF9500",
        type: .expense
    )

    VStack(spacing: VSpacing.lg) {
        RecurringRowView(rule: sampleRule, category: sampleCategory)
            .padding(VSpacing.lg)

        Spacer()
    }
    .background(VColors.background)
}
