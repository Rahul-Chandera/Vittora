import SwiftUI
import VittoraCore

struct SavingsGoalCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let goal: SavingsGoalEntity
    let currencyCode: String

    var body: some View {
        VCard {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                : AnyLayout(HStackLayout(spacing: VSpacing.md))
            layout {
                SavingsProgressRingView(
                    progress: goal.progressFraction,
                    color: VColors.textPrimary,
                    size: 60,
                    lineWidth: 6
                )

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    HStack {
                        Image(systemName: goal.category.systemImage)
                            .font(.caption)
                            .foregroundStyle(VColors.textPrimary)
                            .accessibilityHidden(true)
                        Text(goal.name)
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                            .adaptiveLineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        statusBadge
                    }

                    // Amount progress
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            amountProgress
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            amountProgress
                        }
                    }

                    // Deadline / days remaining
                    if let days = goal.daysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: days < 0 ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.caption)
                                .foregroundStyle(VColors.textPrimary)
                                .accessibilityHidden(true)
                            Text(deadlineLabel(days: days))
                                .font(VTypography.caption2)
                                .foregroundStyle(VColors.textPrimary)
                        }
                    }

                    if let monthly = goal.monthlySavingsNeeded, goal.status == .active {
                        Text(
                            String(
                                localized: "Save \(monthly.formatted(.currency(code: currencyCode)))/month"
                            )
                        )
                        .font(VTypography.caption2.bold())
                        .foregroundStyle(VColors.textPrimary)
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(VColors.textSecondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(String(localized: "Tap to view goal details"))
    }

    @ViewBuilder
    private var amountProgress: some View {
        Text(goal.currentAmount.formatted(.currency(code: currencyCode)))
            .font(VTypography.caption1.bold())
            .foregroundStyle(VColors.textPrimary)
        Text(String(localized: "of"))
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textPrimary)
        Text(goal.targetAmount.formatted(.currency(code: currencyCode)))
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textPrimary)
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
                .foregroundStyle(VColors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.tertiaryBackground)
                .clipShape(Capsule())
        case .paused:
            Text(String(localized: "Paused"))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.tertiaryBackground)
                .clipShape(Capsule())
        case .cancelled:
            Text(String(localized: "Cancelled"))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(VColors.tertiaryBackground)
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
