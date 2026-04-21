import SwiftUI
import Charts

struct IncomeExpenseBarChart: View {
    let data: [MonthlyData]
    var currencyCode: String = "USD"

    var body: some View {
        Chart {
            ForEach(data) { item in
                BarMark(
                    x: .value(String(localized: "Month"), item.month, unit: .month),
                    y: .value(String(localized: "Income"), item.income),
                    width: .ratio(0.4)
                )
                .foregroundStyle(VColors.income)
                .position(by: .value(String(localized: "Type"), String(localized: "Income")))
                .cornerRadius(3)
                .accessibilityLabel(String(localized: "Income"))
                .accessibilityValue(item.income.formatted(.currency(code: currencyCode)))

                BarMark(
                    x: .value(String(localized: "Month"), item.month, unit: .month),
                    y: .value(String(localized: "Expense"), item.expense),
                    width: .ratio(0.4)
                )
                .foregroundStyle(VColors.expense)
                .position(by: .value(String(localized: "Type"), String(localized: "Expense")))
                .cornerRadius(3)
                .accessibilityLabel(String(localized: "Expense"))
                .accessibilityValue(item.expense.formatted(.currency(code: currencyCode)))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(VTypography.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(compactAmount(amount))
                            .font(VTypography.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartLegend(position: .top, alignment: .trailing) {
            HStack(spacing: VSpacing.md) {
                legendItem(color: VColors.income, label: String(localized: "Income"))
                legendItem(color: VColors.expense, label: String(localized: "Expense"))
            }
        }
        .accessibilityChartDescriptor(
            MonthlyIncomeExpenseChartDescriptor(
                data: data,
                currencyCode: currencyCode
            )
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: VSpacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
    }

    private func compactAmount(_ amount: Double) -> String {
        let symbol = currencySymbol
        if amount >= 1000 {
            return String(format: "\(symbol)%.0fk", amount / 1000)
        }
        return String(format: "\(symbol)%.0f", amount)
    }

    private var currencySymbol: String {
        String.currencySymbol(for: currencyCode)
    }
}

#Preview {
    IncomeExpenseBarChart(data: [])
        .frame(height: 200)
        .padding()
}
