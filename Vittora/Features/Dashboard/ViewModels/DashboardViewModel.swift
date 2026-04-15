import Foundation
import Observation
import os.signpost

@Observable
@MainActor
final class DashboardViewModel {
    var dashboardData: DashboardData?
    var comparison: MonthComparison?
    var isLoading = false
    var error: String?

    private let dashboardDataUseCase: DashboardDataUseCase
    private let monthComparisonUseCase: MonthComparisonUseCase

    init(
        dashboardDataUseCase: DashboardDataUseCase,
        monthComparisonUseCase: MonthComparisonUseCase
    ) {
        self.dashboardDataUseCase = dashboardDataUseCase
        self.monthComparisonUseCase = monthComparisonUseCase
    }

    func load() async {
        let signpostID = PerformanceLogger.Dashboard.beginLoad()
        defer { PerformanceLogger.Dashboard.endLoad(id: signpostID) }

        isLoading = true
        error = nil

        do {
            async let dataTask = dashboardDataUseCase.execute()
            async let comparisonTask = monthComparisonUseCase.execute()
            let (data, comp) = try await (dataTask, comparisonTask)
            dashboardData = data
            comparison = comp
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Formatted helpers

    func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    func formattedPercent(_ value: Double) -> String {
        let formatted = String(format: "%.1f", abs(value))
        return "\(formatted)%"
    }
}
