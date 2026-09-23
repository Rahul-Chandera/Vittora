import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class MonthlyOverviewViewModel {
    var monthlyData: [MonthlyData] = []
    var isLoading = false
    var error: String?

    /// Optional Apple Intelligence summary of the latest month (M3.2.6). Nil
    /// until it has been produced; the feature is an enhancement, so the report
    /// is complete without it.
    var summary: SpendingSummaryService.Summary?

    var totalIncome: Decimal { monthlyData.reduce(Decimal(0)) { $0 + $1.income } }
    var totalExpense: Decimal { monthlyData.reduce(Decimal(0)) { $0 + $1.expense } }
    var netSavings: Decimal { totalIncome - totalExpense }

    private let useCase: MonthlyOverviewUseCase
    private let summaryService = SpendingSummaryService()

    init(useCase: MonthlyOverviewUseCase) {
        self.useCase = useCase
    }

    /// `year: nil` keeps the rolling 12-month window (Monthly Overview);
    /// passing a year scopes to that calendar year (Annual Summary).
    func load(year: Int? = nil) async {
        isLoading = true
        error = nil
        do {
            if let year {
                monthlyData = try await useCase.execute(year: year)
            } else {
                monthlyData = try await useCase.execute(monthCount: 12)
            }
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load the monthly report right now.")
            )
        }
        await refreshSummary()
        isLoading = false
    }

    /// Summarises the most recent month. Every figure is taken from the data
    /// already computed above — the model is only ever asked to phrase them,
    /// and its output is validated before it is shown.
    private func refreshSummary() async {
        guard let latest = monthlyData.last else {
            summary = nil
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        summary = await summaryService.summarise(
            SpendingSummaryService.Facts(
                monthName: formatter.string(from: latest.month),
                totalSpent: latest.expense,
                totalIncome: latest.income,
                currencyCode: CurrencyDefaults.code
            )
        )
    }
}
