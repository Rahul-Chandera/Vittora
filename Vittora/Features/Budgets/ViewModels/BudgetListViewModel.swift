import Foundation

@Observable
@MainActor
final class BudgetListViewModel {
    var budgets: [BudgetEntity] = []
    var budgetProgress: [UUID: BudgetProgress] = [:]
    var overallSpent: Decimal = 0
    var overallBudget: Decimal = 0
    var selectedPeriod: BudgetPeriod = .monthly
    var isLoading = false
    var error: String?

    private let fetchUseCase: FetchBudgetsUseCase
    private let deleteUseCase: DeleteBudgetUseCase
    private let calculateProgressUseCase: CalculateBudgetProgressUseCase

    init(
        fetchUseCase: FetchBudgetsUseCase,
        deleteUseCase: DeleteBudgetUseCase,
        calculateProgressUseCase: CalculateBudgetProgressUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
        self.calculateProgressUseCase = calculateProgressUseCase
    }

    func loadBudgets() async {
        isLoading = true
        error = nil
        do {
            var allBudgets = try await fetchUseCase.execute()

            // Filter by selected period
            allBudgets = allBudgets.filter { $0.period == selectedPeriod }
            self.budgets = allBudgets.sorted { $0.startDate > $1.startDate }

            // Calculate progress for each
            budgetProgress.removeAll()
            for budget in budgets {
                budgetProgress[budget.id] = calculateProgressUseCase.execute(budget: budget)
            }

            // Calculate overall totals
            overallBudget = budgets.reduce(0) { $0 + $1.amount }
            overallSpent = budgets.reduce(0) { $0 + $1.spent }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteBudget(id: UUID) async {
        do {
            try await deleteUseCase.execute(id: id)
            await loadBudgets()
        } catch {
            self.error = error.localizedDescription
        }
    }

    var overallProgress: Double {
        guard overallBudget > 0 else { return 0 }
        return Double(truncating: (overallSpent / overallBudget) as NSDecimalNumber)
    }
}
