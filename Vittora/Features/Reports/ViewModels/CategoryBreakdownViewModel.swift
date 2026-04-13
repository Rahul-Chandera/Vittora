import Foundation
import Observation

@Observable
@MainActor
final class CategoryBreakdownViewModel {
    var breakdowns: [CategoryBreakdown] = []
    var selectedType: TransactionType = .expense
    var dateRange: ClosedRange<Date>?
    var isLoading = false
    var error: String?

    var total: Decimal { breakdowns.reduce(Decimal(0)) { $0 + $1.amount } }

    private let useCase: CategoryBreakdownUseCase

    init(useCase: CategoryBreakdownUseCase) {
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
            breakdowns = try await useCase.execute(dateRange: dateRange, type: selectedType)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func applyDateRange(_ range: ClosedRange<Date>?) async {
        dateRange = range
        await load()
    }

    func applyType(_ type: TransactionType) async {
        selectedType = type
        await load()
    }
}
