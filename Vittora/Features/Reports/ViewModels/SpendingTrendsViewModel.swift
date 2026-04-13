import Foundation
import Observation

@Observable
@MainActor
final class SpendingTrendsViewModel {
    var dataPoints: [TrendDataPoint] = []
    var grouping: TrendGrouping = .daily
    var selectedType: TransactionType = .expense
    var dateRange: ClosedRange<Date>?
    var isLoading = false
    var error: String?

    var totalAmount: Decimal { dataPoints.reduce(Decimal(0)) { $0 + $1.amount } }
    var averageAmount: Decimal {
        dataPoints.isEmpty ? 0 : totalAmount / Decimal(dataPoints.count)
    }
    var peakAmount: Decimal { dataPoints.max(by: { $0.amount < $1.amount })?.amount ?? 0 }

    private let useCase: SpendingTrendsUseCase

    init(useCase: SpendingTrendsUseCase) {
        self.useCase = useCase
        let calendar = Calendar.current
        let now = Date.now
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now
        dateRange = monthStart...now
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            dataPoints = try await useCase.execute(
                dateRange: dateRange,
                grouping: grouping,
                type: selectedType
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyGrouping(_ grouping: TrendGrouping) async {
        self.grouping = grouping
        await load()
    }

    func applyDateRange(_ range: ClosedRange<Date>?) async {
        dateRange = range
        await load()
    }
}
