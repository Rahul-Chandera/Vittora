import Foundation
import Accessibility
import SwiftUI

enum ChartAccessibilitySupport {
    static func currencyString(for value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? value.formatted()
    }

    static func numericRange(for values: [Double], includeZero: Bool = false) -> ClosedRange<Double> {
        let rangeValues = includeZero ? values + [0] : values
        guard let lower = rangeValues.min(), let upper = rangeValues.max() else {
            return 0...1
        }

        if lower == upper {
            let padding = max(Swift.abs(lower) * 0.1, 1)
            return (lower - padding)...(upper + padding)
        }

        let padding = max((upper - lower) * 0.1, 1)
        return (lower - padding)...(upper + padding)
    }

    static func gridlines(for range: ClosedRange<Double>, segments: Int = 4) -> [Double] {
        let segmentCount = max(segments, 1)
        let lower = range.lowerBound
        let delta = range.upperBound - range.lowerBound
        return (0...segmentCount).map { index in
            lower + delta * Double(index) / Double(segmentCount)
        }
    }

    static func monthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide))
    }

    static func fullDateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func dayLabel(_ day: Int) -> String {
        String(localized: "Day \(day)")
    }

    static func dataSeries(
        name: String,
        isContinuous: Bool,
        points: [AXDataPoint]
    ) -> AXDataSeriesDescriptor {
        AXDataSeriesDescriptor(
            name: name,
            isContinuous: isContinuous,
            dataPoints: points
        )
    }
}

struct MonthlyIncomeExpenseChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let data: [MonthlyData]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = data.map { ChartAccessibilitySupport.monthLabel($0.month) }
        let amounts = data.flatMap {
            [
                Double(truncating: $0.income as NSDecimalNumber),
                Double(truncating: $0.expense as NSDecimalNumber),
            ]
        }
        let range = ChartAccessibilitySupport.numericRange(for: amounts, includeZero: true)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Month"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Amount"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let incomeSeries = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Income"),
            isContinuous: false,
            points: zip(labels, data).map { label, item in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: item.income as NSDecimalNumber),
                    label: String(localized: "\(label) income")
                )
            }
        )
        let expenseSeries = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Expense"),
            isContinuous: false,
            points: zip(labels, data).map { label, item in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: item.expense as NSDecimalNumber),
                    label: String(localized: "\(label) expense")
                )
            }
        )

        return AXChartDescriptor(
            title: String(localized: "Income vs Expenses"),
            summary: String(localized: "Shows monthly income and expense totals."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [incomeSeries, expenseSeries]
        )
    }
}

struct MonthlyNetCashFlowChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let data: [MonthlyData]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = data.map { ChartAccessibilitySupport.monthLabel($0.month) }
        let values = data.map { Double(truncating: $0.net as NSDecimalNumber) }
        let range = ChartAccessibilitySupport.numericRange(for: values, includeZero: true)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Month"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Net cash flow"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let series = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Net cash flow"),
            isContinuous: false,
            points: zip(labels, data).map { label, item in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: item.net as NSDecimalNumber),
                    label: String(localized: "\(label) net cash flow")
                )
            }
        )

        return AXChartDescriptor(
            title: String(localized: "Monthly Net Cash Flow"),
            summary: String(localized: "Shows each month as either surplus or deficit."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}

struct SpendingTrendChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let dataPoints: [TrendDataPoint]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = dataPoints.map { ChartAccessibilitySupport.fullDateLabel($0.date) }
        let values = dataPoints.map { Double(truncating: $0.amount as NSDecimalNumber) }
        let range = ChartAccessibilitySupport.numericRange(for: values, includeZero: true)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Period"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Amount"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let series = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Spending"),
            isContinuous: true,
            points: zip(labels, dataPoints).map { label, point in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: point.amount as NSDecimalNumber),
                    label: label
                )
            }
        )

        return AXChartDescriptor(
            title: String(localized: "Spending Trend"),
            summary: String(localized: "Shows how spending changes over time."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}

struct CategoryBreakdownChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let breakdowns: [CategoryBreakdown]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let categories = Array(breakdowns.prefix(8))
        let labels = categories.map(\.category.name)
        let values = categories.map { Double(truncating: $0.amount as NSDecimalNumber) }
        let range = ChartAccessibilitySupport.numericRange(for: values, includeZero: true)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Category"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Amount"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let series = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Category Breakdown"),
            isContinuous: false,
            points: categories.map { item in
                AXDataPoint(
                    x: item.category.name,
                    y: Double(truncating: item.amount as NSDecimalNumber),
                    label: String(localized: "\(item.category.name), \(item.transactionCount.formatted()) transactions")
                )
            }
        )

        let descriptor = AXChartDescriptor(
            title: String(localized: "Category Breakdown"),
            summary: String(localized: "Shows the categories contributing the most to the selected period."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
        descriptor.contentDirection = .radialClockwise
        return descriptor
    }
}

struct CategorySpendChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let categories: [CategorySpend]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = categories.map(\.category.name)
        let values = categories.map { Double(truncating: $0.amount as NSDecimalNumber) }
        let range = ChartAccessibilitySupport.numericRange(for: values, includeZero: true)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Category"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Amount"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let series = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Top Categories"),
            isContinuous: false,
            points: categories.map { item in
                AXDataPoint(
                    x: item.category.name,
                    y: Double(truncating: item.amount as NSDecimalNumber),
                    label: item.category.name
                )
            }
        )

        let descriptor = AXChartDescriptor(
            title: String(localized: "Top Categories"),
            summary: String(localized: "Shows the highest-spending categories for the current month."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
        descriptor.contentDirection = .radialClockwise
        return descriptor
    }
}

struct DailySpendAccessibilityChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let points: [(day: Int, amount: Decimal)]
    let dailyBudgetAverage: Decimal
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = points.map { ChartAccessibilitySupport.dayLabel($0.day) }
        let spendValues = points.map { Double(truncating: $0.amount as NSDecimalNumber) }
        let budgetValue = Double(truncating: dailyBudgetAverage as NSDecimalNumber)
        let range = ChartAccessibilitySupport.numericRange(
            for: spendValues + [budgetValue],
            includeZero: true
        )
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Day"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Daily spend"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let spendSeries = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Daily Spend"),
            isContinuous: false,
            points: zip(labels, points).map { label, point in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: point.amount as NSDecimalNumber),
                    label: label
                )
            }
        )
        let budgetSeries = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Daily Budget"),
            isContinuous: true,
            points: labels.map { label in
                AXDataPoint(
                    x: label,
                    y: budgetValue,
                    label: String(localized: "\(label) budget average")
                )
            }
        )

        return AXChartDescriptor(
            title: String(localized: "Daily Spending"),
            summary: String(localized: "Shows daily spending compared with the average daily budget."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [spendSeries, budgetSeries]
        )
    }
}

struct BalanceHistoryChartDescriptor: AXChartDescriptorRepresentable, Sendable {
    let dataPoints: [BalanceDataPoint]
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = dataPoints.map { ChartAccessibilitySupport.fullDateLabel($0.date) }
        let balances = dataPoints.map { Double(truncating: $0.balance as NSDecimalNumber) }
        let range = ChartAccessibilitySupport.numericRange(for: balances, includeZero: false)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Date"),
            categoryOrder: labels
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Balance"),
            range: range,
            gridlinePositions: ChartAccessibilitySupport.gridlines(for: range)
        ) { value in
            ChartAccessibilitySupport.currencyString(for: value, currencyCode: currencyCode)
        }

        let series = ChartAccessibilitySupport.dataSeries(
            name: String(localized: "Balance"),
            isContinuous: true,
            points: zip(labels, dataPoints).map { label, point in
                AXDataPoint(
                    x: label,
                    y: Double(truncating: point.balance as NSDecimalNumber),
                    label: label
                )
            }
        )

        return AXChartDescriptor(
            title: String(localized: "Balance History"),
            summary: String(localized: "Shows balance changes over time."),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
