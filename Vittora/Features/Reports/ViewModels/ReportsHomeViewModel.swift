import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class ReportsHomeViewModel {
    var monthSpending: Decimal = 0
    var monthIncome: Decimal = 0
    var isLoading = false
    var error: String?
    var insights: [SpendingInsight] = []

    private let transactionRepository: any TransactionRepository
    private let insightsUseCase: EvaluateSpendingInsightsUseCase?

    init(
        transactionRepository: any TransactionRepository,
        insightsUseCase: EvaluateSpendingInsightsUseCase? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.insightsUseCase = insightsUseCase
    }

    func dismiss(_ insight: SpendingInsight) {
        insightsUseCase?.dismiss(insight)
        insights.removeAll { $0.id == insight.id }
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let calendar = Calendar.current
            let now = Date.now
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now

            let filter = TransactionFilter(dateRange: monthStart...now)
            let transactions = try await transactionRepository.fetchAll(filter: filter)

            monthSpending = transactions
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }

            monthIncome = transactions
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
            // Insights are secondary: a failure here must not take the month summary and
            // the report list down with it.
            insights = (try? await insightsUseCase?.execute()) ?? []
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load report highlights right now.")
            )
        }
        isLoading = false
    }
}
