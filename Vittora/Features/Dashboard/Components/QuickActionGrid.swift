import SwiftUI

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let destination: NavigationDestination
    let accessibilityIdentifier: String
}

struct QuickActionGrid: View {
    let onAction: (NavigationDestination) -> Void

    private let actions: [QuickAction] = [
        QuickAction(
            title: String(localized: "Expense"),
            icon: "arrow.up.circle.fill",
            color: VColors.expense,
            destination: .addTransaction,
            accessibilityIdentifier: "quick-action-expense-button"
        ),
        QuickAction(
            title: String(localized: "Income"),
            icon: "arrow.down.circle.fill",
            color: VColors.income,
            destination: .addTransaction,
            accessibilityIdentifier: "quick-action-income-button"
        ),
        QuickAction(
            title: String(localized: "Transfer"),
            icon: "arrow.left.arrow.right.circle.fill",
            color: VColors.transfer,
            destination: .addTransfer,
            accessibilityIdentifier: "quick-action-transfer-button"
        ),
        QuickAction(
            title: String(localized: "Budget"),
            icon: "target",
            color: VColors.primary,
            destination: .addBudget,
            accessibilityIdentifier: "quick-action-budget-button"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Quick Actions"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.md) {
                    ForEach(actions) { action in
                        QuickActionButton(action: action) {
                            onAction(action.destination)
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

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: VSpacing.sm) {
                Image(systemName: action.icon)
                    .font(.system(size: 28))
                    .foregroundColor(action.color)
                    .frame(width: 56, height: 56)
                    .background(action.color.opacity(0.12))
                    .clipShape(Circle())

                Text(action.title)
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textPrimary)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

#Preview {
    QuickActionGrid(onAction: { _ in })
        .padding()
}
