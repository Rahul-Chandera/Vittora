import Foundation
import VittoraCore

@Observable
@MainActor
final class CashFlowForecastViewModel {
    var result: CashFlowForecastResult?
    /// The currency the projection is in — see the use case. nil falls back to
    /// the display currency.
    var projectedCurrencyCode: String?
    var isLoading = false
    var error: String?

    private let useCase: CashFlowForecastUseCase

    init(useCase: CashFlowForecastUseCase) {
        self.useCase = useCase
    }

    var chartPoints: [TrendDataPoint] {
        (result?.points ?? []).map { point in
            TrendDataPoint(date: point.date, amount: point.balance)
        }
    }

    var day30Balance: Decimal? {
        result?.balance(atDayOffset: 30)
    }

    var day90Balance: Decimal? {
        result?.balance(atDayOffset: 90)
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            result = try await useCase.execute()
            projectedCurrencyCode = try? await useCase.projectedCurrencyCode()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load the cash flow forecast right now.")
            )
        }
        isLoading = false
    }
}
