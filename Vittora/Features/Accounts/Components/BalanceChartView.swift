import SwiftUI
import Charts

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
}

struct BalanceChartView: View {
    let dataPoints: [BalanceDataPoint]
    var currencyCode: String = CurrencyDefaults.code
    var height: CGFloat = 120

    private var minBalance: Double {
        dataPoints.map { Double(truncating: $0.balance as NSDecimalNumber) }.min() ?? 0
    }

    private var maxBalance: Double {
        dataPoints.map { Double(truncating: $0.balance as NSDecimalNumber) }.max() ?? 1
    }

    var body: some View {
        if dataPoints.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var emptyState: some View {
        VStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(VColors.textTertiary)
            Text(String(localized: "No balance history"))
                .font(VTypography.caption1)
                .foregroundColor(VColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var chartContent: some View {
        Chart(dataPoints) { point in
            let bal = Double(truncating: point.balance as NSDecimalNumber)
            LineMark(
                x: .value("Date", point.date),
                y: .value("Balance", bal)
            )
            .foregroundStyle(VColors.primary)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", minBalance),
                yEnd: .value("Balance", bal)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [VColors.primary.opacity(0.3), VColors.primary.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: height)
        .accessibilityChartDescriptor(
            BalanceHistoryChartDescriptor(
                dataPoints: dataPoints,
                currencyCode: currencyCode
            )
        )
    }
}

#Preview {
    let now = Date()
    let points = (0..<12).map { i in
        BalanceDataPoint(
            date: Calendar.current.date(byAdding: .month, value: -11 + i, to: now) ?? now,
            balance: Decimal(Double.random(in: 2000...5000))
        )
    }
    return BalanceChartView(dataPoints: points)
        .padding(VSpacing.screenPadding)
        .background(VColors.background)
}
