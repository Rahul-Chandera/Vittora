import SwiftUI

struct SavingsGoalCardView: View {
    let goal: SavingsGoalEntity
    let currencyCode: String

    private var goalColor: Color { Color(hex: goal.colorHex) ?? VColors.primary }

    var body: some View {
        VCard {
            HStack(spacing: VSpacing.md) {
                SavingsProgressRingView(
                    progress: goal.progressFraction,
                    color: goalColor,
                    size: 60,
                    lineWidth: 6
                )

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    HStack {
                        Image(systemName: goal.category.systemImage)
                            .font(.caption)
                            .foregroundStyle(goalColor)
                        Text(goal.name)
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                            .adaptiveLineLimit(1)
                        Spacer()
                        statusBadge
                    }

                    // Amount progress
                    HStack(spacing: 4) {
                        Text(goal.currentAmount.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(goalColor)
                        Text(String(localized: "of"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(goal.targetAmount.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }

                    // Deadline / days remaining
                    if let days = goal.daysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: days < 0 ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.caption2)
                                .foregroundStyle(days < 0 ? VColors.expense : VColors.textSecondary)
                            Text(deadlineLabel(days: days))
                                .font(VTypography.caption2)
                                .foregroundStyle(days < 0 ? VColors.expense : VColors.textSecondary)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(String(localized: "Tap to view goal details"))
    }

    private var cardAccessibilityLabel: String {
        let progress = Int(goal.progressFraction * 100)
        let saved = goal.currentAmount.formatted(.currency(code: currencyCode))
        let target = goal.targetAmount.formatted(.currency(code: currencyCode))
        var label = "\(goal.name), \(progress)% complete, \(saved) of \(target)"
        if let days = goal.daysRemaining {
            label += ", \(deadlineLabel(days: days))"
        }
        return label
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch goal.status {
        case .active:
            EmptyView()
        case .achieved:
            Text(String(localized: "✓ Done"))
                .font(VTypography.caption2.bold())
                .foregroundStyle(VColors.income)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.income.opacity(0.12))
                .clipShape(Capsule())
        case .paused:
            Text(String(localized: "Paused"))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.secondaryBackground)
                .clipShape(Capsule())
        case .cancelled:
            Text(String(localized: "Cancelled"))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.expense)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.expense.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func deadlineLabel(days: Int) -> String {
        if days < 0 { return String(localized: "\(abs(days)) days overdue") }
        if days == 0 { return String(localized: "Due today") }
        if days == 1 { return String(localized: "1 day left") }
        return String(localized: "\(days) days left")
    }
}
