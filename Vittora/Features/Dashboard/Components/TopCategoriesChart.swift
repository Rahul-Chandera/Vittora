import SwiftUI
import Charts
import VittoraCore

struct TopCategoriesChart: View {
    let categories: [CategorySpend]
    var currencyCode: String = CurrencyDefaults.code

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Top Categories"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            if categories.isEmpty {
                Text(String(localized: "No spending data this month"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
            } else {
                HStack(alignment: .center, spacing: VSpacing.xl) {
                    donutChart
                        .frame(width: 120, height: 120)

                    legend
                }
                .padding(VSpacing.md)
                .background(VColors.secondaryGroupedBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
            }
        }
    }

    private var donutChart: some View {
        Chart(Array(categories.enumerated()), id: \.offset) { index, item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(categoryColor(at: index))
            .accessibilityLabel(item.category.displayName)
            .accessibilityValue(item.amount.formatted(.currency(code: currencyCode)))
        }
        .accessibilityChartDescriptor(
            CategorySpendChartDescriptor(
                categories: categories,
                currencyCode: currencyCode
            )
        )
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            ForEach(Array(categories.enumerated()), id: \.offset) { index, item in
                HStack(spacing: VSpacing.sm) {
                    Circle()
                        .fill(categoryColor(at: index))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text(item.category.displayName)
                        .font(VTypography.body)
                        .foregroundColor(VColors.textPrimary)
                        .adaptiveLineLimit(1)

                    Spacer()

                    // Both name and amount sat at caption here — 10pt, the
                    // smallest tier in the app, for the card's only data.
                    Text(CurrencyFormatter.formatCompact(item.amount, currencyCode: currencyCode))
                        .font(VTypography.amountSmall)
                        .foregroundColor(VColors.textSecondary)
                        .amountScaling(0.85)
                        .layoutPriority(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.category.displayName)
                .accessibilityValue(item.amount.formatted(.currency(code: currencyCode)))
            }
        }
    }

    private func categoryColor(at index: Int) -> Color {
        VColors.categoryColors[index % VColors.categoryColors.count]
    }
}

#Preview {
    TopCategoriesChart(categories: [])
        .padding()
}
