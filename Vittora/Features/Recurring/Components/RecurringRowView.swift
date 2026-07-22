import SwiftUI
import VittoraCore

struct RecurringRowView: View {
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let rule: RecurringRuleEntity
    var category: CategoryEntity? = nil

    private var frequencyLabel: String {
        switch rule.frequency {
        case .daily:
            return String(localized: "Daily")
        case .weekly:
            return String(localized: "Weekly")
        case .biweekly:
            return String(localized: "Bi-weekly")
        case .monthly:
            return String(localized: "Monthly")
        case .quarterly:
            return String(localized: "Quarterly")
        case .yearly:
            return String(localized: "Yearly")
        case .custom(let days):
            return String(localized: "Every \(days)d")
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.sm))
            : AnyLayout(HStackLayout(spacing: VSpacing.md))
        layout {
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
            .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                let titleLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.xxs))
                    : AnyLayout(HStackLayout())
                titleLayout {
                    Text(category?.displayName ?? String(localized: "Uncategorized"))
                        .font(VTypography.calloutBold)
                        .foregroundColor(VColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    // Amount with bold styling; keeps its width so the name
                    // truncates/scales instead of the amount wrapping.
                    Text(rule.templateAmount.formatted(currencyCode: currencyCode))
                        .font(VTypography.calloutBold)
                        .foregroundColor(VColors.expense)
                        .amountScaling()
                        .layoutPriority(1)
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

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            // Status indicator
            VStack(spacing: VSpacing.xxs) {
                Image(systemName: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundColor(rule.isActive ? .green : .orange)
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
            }
        }
        .padding(VSpacing.md)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Shows recurring transaction details"))
    }
}

#Preview {
    let sampleRule = RecurringRuleEntity(
        frequency: .monthly,
        nextDate: Date.now,
        templateAmount: Decimal(localizedAmount: "29.99", locale: Locale(identifier: "en_US_POSIX")) ?? 0
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
