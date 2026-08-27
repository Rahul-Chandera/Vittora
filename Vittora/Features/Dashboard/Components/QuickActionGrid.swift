import SwiftUI
import VittoraCore

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: VColors.IconTint
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
            tint: .red,
            destination: .addTransaction,
            transactionType: .expense,
            accessibilityIdentifier: "quick-action-expense-button",
            accessibilityLabel: String(localized: "Add expense"),
            accessibilityHint: String(localized: "Opens the expense transaction form")
        ),
        QuickAction(
            title: String(localized: "Income"),
            icon: "arrow.down.circle.fill",
            tint: .green,
            destination: .addTransaction,
            transactionType: .income,
            accessibilityIdentifier: "quick-action-income-button",
            accessibilityLabel: String(localized: "Add income"),
            accessibilityHint: String(localized: "Opens the income transaction form")
        ),
        QuickAction(
            title: String(localized: "Transfer"),
            icon: "arrow.left.arrow.right.circle.fill",
            tint: .blue,
            destination: .addTransfer,
            transactionType: nil,
            accessibilityIdentifier: "quick-action-transfer-button",
            accessibilityLabel: String(localized: "Transfer funds"),
            accessibilityHint: String(localized: "Opens the transfer form")
        ),
        QuickAction(
            title: String(localized: "Budget"),
            icon: "target",
            tint: .teal,
            destination: .addBudget,
            transactionType: nil,
            accessibilityIdentifier: "quick-action-budget-button",
            accessibilityLabel: String(localized: "Create budget"),
            accessibilityHint: String(localized: "Opens the budget form")
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sectionHeaderGap) {
            Text(String(localized: "Quick Actions"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            // On a card, like every other section's content. This was the one
            // section whose content sat bare on the page, so the row of
            // circles read as floating rather than as a block belonging to
            // the title above it.
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VSpacing.cardPadding)
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
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
                    // Coloured glyph on its own tint. The earlier 22% wash was
                    // what forced these to textPrimary: at that strength the
                    // glyph measured ~3.9:1 in dark mode. iconTintFill's 14%
                    // keeps the affordance and clears 4.5:1 on white, card, dark
                    // and OLED black — worst case 4.50:1.
                    .font(.title2)
                    .foregroundStyle(VColors.iconTint(action.tint))
                    .frame(width: iconFrame, height: iconFrame)
                    .background(VColors.iconTintFill(action.tint))
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
