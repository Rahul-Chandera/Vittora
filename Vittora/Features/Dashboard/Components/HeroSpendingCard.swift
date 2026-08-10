import SwiftUI
import VittoraCore

struct HeroSpendingCard: View {
    let monthSpending: Decimal
    let monthIncome: Decimal
    let comparison: MonthComparison?
    var currencyCode: String = CurrencyDefaults.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var highContrastText: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "This Month"))
                .font(VTypography.subheadline)
                .foregroundColor(highContrastText)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: VSpacing.xl) {
                    spentColumn
                    Spacer(minLength: 0)
                    incomeColumn
                }
                VStack(alignment: .leading, spacing: VSpacing.md) {
                    spentColumn
                    incomeColumn
                }
            }

            if let comp = comparison {
                savingsBar(rate: comp.savingsRate)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Monthly summary"))
        .accessibilityValue(accessibilitySummary)
    }

    private var spentColumn: some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(String(localized: "Spent"))
                .font(VTypography.bodyBold)
                .foregroundColor(highContrastText)
            Text(CurrencyFormatter.format(monthSpending, currencyCode: currencyCode))
                .font(VTypography.amountLarge)
                .foregroundColor(highContrastText)
                .amountScaling()
            if let comp = comparison {
                spendingTrendLabel(percent: comp.spendingChangePercent)
            }
        }
    }

    private var incomeColumn: some View {
        VStack(alignment: .trailing, spacing: VSpacing.xs) {
            Text(String(localized: "Income"))
                .font(VTypography.bodyBold)
                .foregroundColor(highContrastText)
            Text(CurrencyFormatter.format(monthIncome, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .foregroundColor(highContrastText)
                .amountScaling()
            if let comp = comparison {
                incomeTrendLabel(percent: comp.incomeChangePercent)
            }
        }
    }

    @ViewBuilder
    private func spendingTrendLabel(percent: Double) -> some View {
        let increased = percent > 0
        HStack(spacing: VSpacing.xxs) {
            Image(systemName: increased ? "arrow.up" : "arrow.down")
                .font(.caption)
                .accessibilityHidden(true)
            Text(String(format: "%.1f%%", abs(percent)))
                .font(VTypography.bodyBold)
        }
        .foregroundColor(highContrastText)
    }

    @ViewBuilder
    private func incomeTrendLabel(percent: Double) -> some View {
        let increased = percent > 0
        HStack(spacing: VSpacing.xxs) {
            Image(systemName: increased ? "arrow.up" : "arrow.down")
                .font(.caption)
                .accessibilityHidden(true)
            Text(String(format: "%.1f%%", abs(percent)))
                .font(VTypography.bodyBold)
        }
        .foregroundColor(highContrastText)
    }

    @ViewBuilder
    private func savingsBar(rate: Double) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack {
                Text(String(localized: "Savings Rate"))
                    .font(VTypography.bodyBold)
                    .foregroundColor(highContrastText)
                Spacer()
                Text(String(format: "%.0f%%", rate * 100))
                    .font(VTypography.bodyBold)
                    .foregroundColor(highContrastText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(VColors.tertiaryBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(rate >= 0.2 ? VColors.budgetSafeFill : VColors.warning)
                        .frame(width: geometry.size.width * CGFloat(rate), height: 6)
                        .animation(reduceMotion ? .none : .easeOut(duration: VSpacing.animationStandard), value: rate)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(.top, VSpacing.xs)
    }

    private var accessibilitySummary: String {
        var parts = [
            String(localized: "Spent \(CurrencyFormatter.format(monthSpending, currencyCode: currencyCode))"),
            String(localized: "Income \(CurrencyFormatter.format(monthIncome, currencyCode: currencyCode))")
        ]

        if let comparison {
            parts.append(String(localized: "Savings rate \(Int(comparison.savingsRate * 100)) percent"))
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    HeroSpendingCard(
        monthSpending: Decimal(string: "1450.75") ?? 0,
        monthIncome: Decimal(string: "3200.00") ?? 0,
        comparison: MonthComparison(
            currentMonthSpending: Decimal(string: "1450.75") ?? 0,
            lastMonthSpending: Decimal(string: "1200.00") ?? 0,
            currentMonthIncome: Decimal(string: "3200.00") ?? 0,
            lastMonthIncome: Decimal(string: "3000.00") ?? 0
        )
    )
    .padding()
}
