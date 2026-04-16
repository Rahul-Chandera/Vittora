import Accessibility
import Foundation
import Testing
@testable import Vittora

@Suite("Chart Accessibility Descriptor Tests")
struct ChartAccessibilityDescriptorTests {
    @Test("monthly income and expense descriptor exposes two series")
    func monthlyIncomeExpenseDescriptor() {
        let descriptor = MonthlyIncomeExpenseChartDescriptor(
            data: [
                MonthlyData(month: makeDate(month: 1), income: 2_400, expense: 1_100),
                MonthlyData(month: makeDate(month: 2), income: 2_200, expense: 1_500),
            ],
            currencyCode: "USD"
        ).makeChartDescriptor()

        #expect(descriptor.title == "Income vs Expenses")
        #expect(descriptor.series.count == 2)
    }

    @Test("spending trend descriptor is continuous")
    func spendingTrendDescriptor() {
        let descriptor = SpendingTrendChartDescriptor(
            dataPoints: [
                TrendDataPoint(date: makeDate(month: 3, day: 1), amount: 120),
                TrendDataPoint(date: makeDate(month: 3, day: 2), amount: 180),
            ],
            currencyCode: "USD"
        ).makeChartDescriptor()

        #expect(descriptor.title == "Spending Trend")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.isContinuous == true)
    }

    @Test("category breakdown descriptor uses radial direction")
    func categoryBreakdownDescriptor() {
        let descriptor = CategoryBreakdownChartDescriptor(
            breakdowns: [
                CategoryBreakdown(
                    category: CategoryEntity(name: "Food", icon: "fork.knife"),
                    amount: 320,
                    percentage: 64,
                    transactionCount: 5
                ),
                CategoryBreakdown(
                    category: CategoryEntity(name: "Transport", icon: "car.fill"),
                    amount: 180,
                    percentage: 36,
                    transactionCount: 3
                ),
            ],
            currencyCode: "USD"
        ).makeChartDescriptor()

        #expect(descriptor.title == "Category Breakdown")
        #expect(descriptor.contentDirection == .radialClockwise)
    }

    @Test("daily spend descriptor includes budget average series")
    func dailySpendDescriptor() {
        let descriptor = DailySpendAccessibilityChartDescriptor(
            points: [(day: 1, amount: 25), (day: 2, amount: 40)],
            dailyBudgetAverage: 30,
            currencyCode: "USD"
        ).makeChartDescriptor()

        #expect(descriptor.title == "Daily Spending")
        #expect(descriptor.series.count == 2)
    }

    private func makeDate(month: Int, day: Int = 1) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: month, day: day)
        ) ?? .now
    }
}
