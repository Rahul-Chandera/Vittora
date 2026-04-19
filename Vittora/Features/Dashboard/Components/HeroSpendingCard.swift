import SwiftUI

struct HeroSpendingCard: View {
    let monthSpending: Decimal
    let monthIncome: Decimal
    let comparison: MonthComparison?
    var currencyCode: String = "USD"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "This Month"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            HStack(alignment: .bottom, spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(String(localized: "Spent"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                    Text(formattedAmount(monthSpending))
                        .font(VTypography.amountLarge)
                        .foregroundColor(VColors.expense)
                    if let comp = comparison {
                        spendingTrendLabel(percent: comp.spendingChangePercent)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: VSpacing.xs) {
                    Text(String(localized: "Income"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                    Text(formattedAmount(monthIncome))
                        .font(VTypography.amountMedium)
                        .foregroundColor(VColors.income)
                    if let comp = comparison {
                        incomeTrendLabel(percent: comp.incomeChangePercent)
                    }
                }
            }

            if let comp = comparison {
                savingsBar(rate: comp.savingsRate)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Monthly summary"))
        .accessibilityValue(accessibilitySummary)
    }

    @ViewBuilder
    private func spendingTrendLabel(percent: Double) -> some View {
        let increased = percent > 0
        HStack(spacing: VSpacing.xxs) {
            Image(systemName: increased ? "arrow.up" : "arrow.down")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(String(format: "%.1f%%", abs(percent)))
                .font(VTypography.caption2)
        }
        .foregroundColor(increased ? VColors.expense : VColors.income)
    }

    @ViewBuilder
    private func incomeTrendLabel(percent: Double) -> some View {
        let increased = percent > 0
        HStack(spacing: VSpacing.xxs) {
            Image(systemName: increased ? "arrow.up" : "arrow.down")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(String(format: "%.1f%%", abs(percent)))
                .font(VTypography.caption2)
        }
        .foregroundColor(increased ? VColors.income : VColors.expense)
    }

    @ViewBuilder
    private func savingsBar(rate: Double) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack {
                Text(String(localized: "Savings Rate"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", rate * 100))
                    .font(VTypography.caption2Bold)
                    .foregroundColor(VColors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(VColors.tertiaryBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(rate >= 0.2 ? VColors.income : VColors.warning)
                        .frame(width: geometry.size.width * CGFloat(rate), height: 6)
                        .animation(reduceMotion ? .none : .easeOut(duration: VSpacing.animationStandard), value: rate)
                }
            }
            .frame(height: 6)
        }
        .padding(.top, VSpacing.xs)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }

    private var accessibilitySummary: String {
        var parts = [
            String(localized: "Spent \(formattedAmount(monthSpending))"),
            String(localized: "Income \(formattedAmount(monthIncome))")
        ]

        if let comparison {
            parts.append(String(localized: "Savings rate \(Int(comparison.savingsRate * 100)) percent"))
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    HeroSpendingCard(
        monthSpending: 1450.75,
        monthIncome: 3200.00,
        comparison: MonthComparison(
            currentMonthSpending: 1450.75,
            lastMonthSpending: 1200.00,
            currentMonthIncome: 3200.00,
            lastMonthIncome: 3000.00
        )
    )
    .padding()
}
