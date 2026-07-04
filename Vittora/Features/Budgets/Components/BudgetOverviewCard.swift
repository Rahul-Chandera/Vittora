import SwiftUI
import VittoraCore

struct BudgetOverviewCard: View {
    let spent: Decimal
    let budget: Decimal
    let progress: Double
    var currencyCode: String = CurrencyDefaults.code

    var remaining: Decimal {
        budget - spent
    }

    var body: some View {
        VCard {
            VStack(spacing: VSpacing.lg) {
                // Header
                HStack(alignment: .top, spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(String(localized: "Total Budget"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(budget, size: .title2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: VSpacing.xs) {
                        Text(String(localized: "Progress"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        Text("\(Int(min(progress * 100, 999)))%")
                            .font(VTypography.title2)
                            .foregroundColor(statusColor)
                    }
                }

                // Progress bar
                VProgressBar(
                    spent: spent,
                    limit: budget,
                    showLabel: false,
                    animated: true
                )

                // Stats row
                HStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(String(localized: "Spent"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(spent, size: .body)
                    }

                    Divider()
                        .frame(height: 32)

                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(String(localized: "Remaining"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(remaining, size: .body)
                            .foregroundColor(remaining < 0 ? VColors.budgetDanger : VColors.budgetSafe)
                    }

                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Budget overview"))
        .accessibilityValue(
            String(
                localized: "Total budget \(CurrencyFormatter.format(budget, currencyCode: currencyCode)), spent \(CurrencyFormatter.format(spent, currencyCode: currencyCode)), remaining \(CurrencyFormatter.format(remaining, currencyCode: currencyCode)), \(Int(min(progress * 100, 999))) percent used"
            )
        )
    }

    private var statusColor: Color {
        if progress >= 0.9 {
            return VColors.budgetDanger
        } else if progress >= 0.75 {
            return VColors.budgetWarning
        } else {
            return VColors.budgetSafe
        }
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        BudgetOverviewCard(spent: 750, budget: 1000, progress: 0.75)
        BudgetOverviewCard(spent: 1200, budget: 1000, progress: 1.2)
        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
