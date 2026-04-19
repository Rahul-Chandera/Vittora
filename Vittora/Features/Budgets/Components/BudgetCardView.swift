import SwiftUI

struct BudgetCardView: View {
    let budget: BudgetEntity
    let progress: BudgetProgress?
    let category: CategoryEntity?
    @Environment(\.currencyCode) private var currencyCode

    var body: some View {
        VCard {
            VStack(spacing: VSpacing.md) {
                // Header: Category icon and name
                HStack(spacing: VSpacing.md) {
                    if let category = category {
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: category.colorHex)?.opacity(0.15) ?? Color.blue.opacity(0.15))
                            .cornerRadius(VSpacing.cornerRadiusXL)
                    } else {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VColors.primary)
                            .frame(width: 40, height: 40)
                            .background(VColors.primary.opacity(0.15))
                            .cornerRadius(VSpacing.cornerRadiusXL)
                    }

                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(category?.name ?? "Budget")
                            .font(VTypography.bodyBold)
                            .foregroundColor(VColors.textPrimary)

                        Text(budget.period.rawValue.capitalized)
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: VSpacing.xs) {
                        VAmountText(budget.amount, size: .callout)
                        Text("Budget")
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                    }
                }

                // Progress bar
                VProgressBar(
                    spent: budget.spent,
                    limit: budget.amount,
                    showLabel: false,
                    animated: true
                )

                // Spent vs Total
                HStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text("Spent")
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(budget.spent, size: .caption)
                    }

                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text("Remaining")
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(budget.remaining, size: .caption)
                            .foregroundColor(budget.isOverBudget ? VColors.budgetDanger : VColors.budgetSafe)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: VSpacing.xs) {
                        Text("Progress")
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        Text("\(Int(budget.progress * 100))%")
                            .font(VTypography.caption1Bold)
                            .foregroundColor(statusColor)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var cardAccessibilityLabel: String {
        let name = category?.name ?? String(localized: "Budget")
        let spent = budget.spent.formatted(.currency(code: currencyCode))
        let limit = budget.amount.formatted(.currency(code: currencyCode))
        let pct = Int(budget.progress * 100)
        let status = budget.isOverBudget ? String(localized: "over budget") : String(localized: "\(pct)% used")
        return "\(name) budget, \(spent) of \(limit), \(status)"
    }

    private var statusColor: Color {
        if budget.progress >= 0.9 {
            return VColors.budgetDanger
        } else if budget.progress >= 0.75 {
            return VColors.budgetWarning
        } else {
            return VColors.budgetSafe
        }
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        BudgetCardView(
            budget: BudgetEntity(
                id: UUID(),
                amount: 1000,
                spent: 650,
                period: .monthly,
                startDate: .now
            ),
            progress: nil,
            category: CategoryEntity(
                id: UUID(),
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#34C759",
                type: .expense
            )
        )

        BudgetCardView(
            budget: BudgetEntity(
                id: UUID(),
                amount: 500,
                spent: 480,
                period: .weekly,
                startDate: .now
            ),
            progress: nil,
            category: CategoryEntity(
                id: UUID(),
                name: "Dining",
                icon: "fork.knife",
                colorHex: "#FF6B35",
                type: .expense
            )
        )

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
