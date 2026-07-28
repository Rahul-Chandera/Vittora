import Foundation
import VittoraCore

@Observable
@MainActor
final class YearInReviewViewModel {
    private let useCase: YearInReviewUseCase
    private let preferredCurrencyCode: String
    private let todayProvider: () -> Date
    private let calendar: Calendar

    var isLoading = false
    var error: String?
    var state: YearInReviewScreenState = .thinHistory
    var availableYears: [Int] = []
    var selectedYear: Int?
    var summary: YearInReviewSummary?
    /// Privacy default: shared image must not include amounts.
    var includeAmountsInShare = false

    init(
        useCase: YearInReviewUseCase,
        preferredCurrencyCode: String,
        todayProvider: @escaping () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        self.useCase = useCase
        self.preferredCurrencyCode = preferredCurrencyCode
        self.todayProvider = todayProvider
        self.calendar = calendar
    }

    func load(requestedYear: Int? = nil) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await useCase.load(
                requestedYear: requestedYear ?? selectedYear,
                preferredCurrencyCode: preferredCurrencyCode,
                today: todayProvider(),
                calendar: calendar
            )
            state = result.state
            availableYears = result.availableYears
            selectedYear = result.selectedYear
            summary = result.summary
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectYear(_ year: Int) async {
        selectedYear = year
        await load(requestedYear: year)
    }
}
