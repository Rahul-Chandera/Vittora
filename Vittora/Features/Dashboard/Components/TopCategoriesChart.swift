import SwiftUI
import Charts

struct TopCategoriesChart: View {
    let categories: [CategorySpend]
    var currencyCode: String = "USD"

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
                .background(VColors.secondaryBackground)
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

                    Text(item.category.name)
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textPrimary)
                        .adaptiveLineLimit(1)

                    Spacer()

                    Text(formattedAmount(item.amount))
                        .font(VTypography.caption2Bold)
                        .foregroundColor(VColors.textSecondary)
                }
            }
        }
    }

    private func categoryColor(at index: Int) -> Color {
        VColors.categoryColors[index % VColors.categoryColors.count]
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    TopCategoriesChart(categories: [])
        .padding()
}
