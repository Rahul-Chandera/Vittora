import Foundation
import Observation

@Observable
@MainActor
final class CustomReportViewModel {
    var result: CustomReportResult?
    var grouping: ReportGrouping = .category
    var selectedType: TransactionType? = .expense
    var dateRange: ClosedRange<Date>?
    var isLoading = false
    var error: String?

    private let useCase: CustomReportUseCase

    init(useCase: CustomReportUseCase) {
        self.useCase = useCase
        let calendar = Calendar.current
        let now = Date.now
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now
        dateRange = monthStart...now
    }

    func generate() async {
        isLoading = true
        error = nil
        do {
            result = try await useCase.execute(
                dateRange: dateRange,
                grouping: grouping,
                transactionType: selectedType
            )
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't generate this report right now.")
            )
        }
        isLoading = false
    }
}
