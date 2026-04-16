import SwiftUI
import Charts

struct TrendAreaChart: View {
    let dataPoints: [TrendDataPoint]
    let color: Color
    var currencyCode: String = "USD"

    var body: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Amount", point.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.4), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Amount", point.amount)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value("Amount", point.amount)
            )
            .foregroundStyle(color)
            .symbolSize(dataPoints.count < 15 ? 30 : 0)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(VTypography.caption2)
                    }
                }
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
        .accessibilityChartDescriptor(
            SpendingTrendChartDescriptor(
                dataPoints: dataPoints,
                currencyCode: currencyCode
            )
        )
    }

    private func compactAmount(_ amount: Double) -> String {
        let symbol = currencySymbol
        if amount >= 1000 {
            return String(format: "\(symbol)%.0fk", amount / 1000)
        }
        return String(format: "\(symbol)%.0f", amount)
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol
    }
}

#Preview {
    TrendAreaChart(dataPoints: [], color: VColors.primary)
        .frame(height: 200)
        .padding()
}
