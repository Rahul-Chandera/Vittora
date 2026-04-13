import Foundation
import Observation

@Observable
@MainActor
final class MonthlyOverviewViewModel {
    var monthlyData: [MonthlyData] = []
    var isLoading = false
    var error: String?

    var totalIncome: Decimal { monthlyData.reduce(Decimal(0)) { $0 + $1.income } }
    var totalExpense: Decimal { monthlyData.reduce(Decimal(0)) { $0 + $1.expense } }
    var netSavings: Decimal { totalIncome - totalExpense }

    private let useCase: MonthlyOverviewUseCase

    init(useCase: MonthlyOverviewUseCase) {
        self.useCase = useCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            monthlyData = try await useCase.execute(monthCount: 12)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
