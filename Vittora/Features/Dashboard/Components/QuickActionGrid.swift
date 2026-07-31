import SwiftUI
import VittoraCore

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let destination: NavigationDestination
    let transactionType: TransactionType?
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityHint: String
}

struct QuickActionGrid: View {
    let onAction: (NavigationDestination, TransactionType?) -> Void

    private let actions: [QuickAction] = [
        QuickAction(
            title: String(localized: "Expense"),
            icon: "arrow.up.circle.fill",
            color: VColors.expense,
            destination: .addTransaction,
            transactionType: .expense,
            accessibilityIdentifier: "quick-action-expense-button",
            accessibilityLabel: String(localized: "Add expense"),
            accessibilityHint: String(localized: "Opens the expense transaction form")
        ),
        QuickAction(
            title: String(localized: "Income"),
            icon: "arrow.down.circle.fill",
            color: VColors.income,
            destination: .addTransaction,
            transactionType: .income,
            accessibilityIdentifier: "quick-action-income-button",
            accessibilityLabel: String(localized: "Add income"),
            accessibilityHint: String(localized: "Opens the income transaction form")
        ),
        QuickAction(
            title: String(localized: "Transfer"),
            icon: "arrow.left.arrow.right.circle.fill",
            color: VColors.transfer,
            destination: .addTransfer,
            transactionType: nil,
            accessibilityIdentifier: "quick-action-transfer-button",
            accessibilityLabel: String(localized: "Transfer funds"),
            accessibilityHint: String(localized: "Opens the transfer form")
        ),
        QuickAction(
            title: String(localized: "Budget"),
            icon: "target",
            color: VColors.primary,
            destination: .addBudget,
            transactionType: nil,
            accessibilityIdentifier: "quick-action-budget-button",
            accessibilityLabel: String(localized: "Create budget"),
            accessibilityHint: String(localized: "Opens the budget form")
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Quick Actions"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.md) {
                    ForEach(actions) { action in
                        QuickActionButton(action: action) {
                            onAction(action.destination, action.transactionType)
                        }
                    }
                }
                .padding(.horizontal, VSpacing.xxs)
                .padding(.vertical, VSpacing.xs)
            }
        }
    }
}

private struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    @ScaledMetric(relativeTo: .title) private var iconFrame: CGFloat = 56

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: VSpacing.sm) {
                Image(systemName: action.icon)
                    // Colored glyph on a 12% tint circle fails AA on OLED black
                    // (~4.2:1). Keep the tint for affordance; draw the symbol in
                    // the WCAG text token instead.
                    .font(.title2)
                    .foregroundStyle(VColors.textPrimary)
                    .frame(width: iconFrame, height: iconFrame)
                    .background(action.color.opacity(0.22))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(action.title)
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textPrimary)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityHint(action.accessibilityHint)
    }
}

#Preview {
    QuickActionGrid(onAction: { _, _ in })
        .padding()
}
