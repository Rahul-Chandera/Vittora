import SwiftUI
import Charts

struct DailySpendChart: View {
    let transactions: [TransactionEntity]
    let dailyBudgetAverage: Decimal
    var currencyCode: String = CurrencyDefaults.code

    var dailySpendData: [(day: Int, amount: Decimal)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.day, from: transaction.date)
        }

        let sorted = grouped.sorted { $0.key < $1.key }
        return sorted.map { day, transactionList in
            let total = transactionList.reduce(0) { $0 + $1.amount }
            return (day, total)
        }
    }

    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Daily Spending"))
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)

                if transactions.isEmpty {
                    VStack(spacing: VSpacing.md) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 32))
                            .foregroundColor(VColors.textTertiary)

                        Text(String(localized: "No transactions yet"))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 150)
                } else {
                    Chart {
                        ForEach(dailySpendData, id: \.day) { data in
                            BarMark(
                                x: .value("Day", data.day),
                                y: .value("Amount", Double(truncating: data.amount as NSDecimalNumber))
                            )
                            .foregroundStyle(barColor(for: data.amount))
                        }

                        // Reference line for daily average
                        RuleMark(y: .value("Budget Avg", Double(truncating: dailyBudgetAverage as NSDecimalNumber)))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundStyle(VColors.budgetWarning.opacity(0.6))
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .accessibilityChartDescriptor(
                        DailySpendAccessibilityChartDescriptor(
                            points: dailySpendData,
                            dailyBudgetAverage: dailyBudgetAverage,
                            currencyCode: currencyCode
                        )
                    )
                }

                // Legend
                HStack(spacing: VSpacing.lg) {
                    HStack(spacing: VSpacing.xs) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VColors.budgetSafe)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "Daily Spend"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                    }

                    HStack(spacing: VSpacing.xs) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(VColors.budgetWarning, lineWidth: 1.5)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "Daily Budget"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private func barColor(for amount: Decimal) -> Color {
        let avgDouble = Double(truncating: dailyBudgetAverage as NSDecimalNumber)
        let amountDouble = Double(truncating: amount as NSDecimalNumber)

        if amountDouble > avgDouble * 1.1 {
            return VColors.budgetDanger
        } else if amountDouble > avgDouble {
            return VColors.budgetWarning
        } else {
            return VColors.budgetSafe
        }
    }
}

#Preview {
    let transactions = [
        TransactionEntity(id: UUID(), amount: 25, date: Date().addingTimeInterval(-86400 * 5), type: .expense),
        TransactionEntity(id: UUID(), amount: 15, date: Date().addingTimeInterval(-86400 * 5), type: .expense),
        TransactionEntity(id: UUID(), amount: 35, date: Date().addingTimeInterval(-86400 * 4), type: .expense),
        TransactionEntity(id: UUID(), amount: 20, date: Date().addingTimeInterval(-86400 * 3), type: .expense),
        TransactionEntity(id: UUID(), amount: 45, date: Date().addingTimeInterval(-86400 * 2), type: .expense),
        TransactionEntity(id: UUID(), amount: 30, date: Date().addingTimeInterval(-86400), type: .expense),
        TransactionEntity(id: UUID(), amount: 50, date: Date(), type: .expense),
    ]

    VStack(spacing: VSpacing.lg) {
        DailySpendChart(transactions: transactions, dailyBudgetAverage: 40)
        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
