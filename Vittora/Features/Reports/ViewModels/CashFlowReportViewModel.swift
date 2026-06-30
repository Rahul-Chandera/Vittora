import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class CashFlowReportViewModel {
    var months: [CashFlowMonth] = []
    var averageDiscretionaryExpense: Decimal = 0
    var averageIncome: Decimal = 0
    var isLoading = false
    var error: String?

    var actualMonths: [CashFlowMonth] {
        months.filter { !$0.isProjected }
    }

    var projectedMonths: [CashFlowMonth] {
        months.filter(\.isProjected)
    }

    var projectedNetTotal: Decimal {
        projectedMonths.reduce(Decimal(0)) { $0 + $1.net }
    }

    private let useCase: CashFlowProjectionUseCase

    init(useCase: CashFlowProjectionUseCase) {
        self.useCase = useCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let result = try await useCase.execute()
            months = result.months
            averageDiscretionaryExpense = result.averageDiscretionaryExpense
            averageIncome = result.averageIncome
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load the cash flow report right now.")
            )
        }
        isLoading = false
    }
}
