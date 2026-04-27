import Foundation

@Observable
@MainActor
final class BudgetDetailViewModel {
    var budget: BudgetEntity?
    var progress: BudgetProgress?
    var category: CategoryEntity?
    var recentTransactions: [TransactionEntity] = []
    var isLoading = false
    var error: String?

    private let budgetRepository: any BudgetRepository
    private let categoryRepository: any CategoryRepository
    private let transactionRepository: any TransactionRepository
    private let calculateProgressUseCase: CalculateBudgetProgressUseCase

    init(
        budgetRepository: any BudgetRepository,
        categoryRepository: any CategoryRepository,
        transactionRepository: any TransactionRepository,
        calculateProgressUseCase: CalculateBudgetProgressUseCase
    ) {
        self.budgetRepository = budgetRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.calculateProgressUseCase = calculateProgressUseCase
    }

    func loadBudget(id: UUID) async {
        isLoading = true
        error = nil
        do {
            guard var loadedBudget = try await budgetRepository.fetchByID(id) else {
                error = String(localized: "We couldn't find this budget.")
                return
            }

            // Calculate spent
            let dateRange = calculateDateRange(for: loadedBudget.period, startingFrom: loadedBudget.startDate)
            let filter = TransactionFilter(
                dateRange: dateRange,
                types: Set([.expense]),
                categoryIDs: loadedBudget.categoryID.map { Set([$0]) }
            )
            let transactions = try await transactionRepository.fetchAll(filter: filter)
            loadedBudget.spent = transactions.reduce(0) { $0 + $1.amount }

            self.budget = loadedBudget
            self.progress = calculateProgressUseCase.execute(budget: loadedBudget)

            // Load category if exists
            if let categoryID = loadedBudget.categoryID {
                self.category = try await categoryRepository.fetchByID(categoryID)
            }

            // Load recent transactions (last 5)
            self.recentTransactions = Array(transactions.sorted { $0.date > $1.date }.prefix(5))
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load this budget right now.")
            )
        }
        isLoading = false
    }

    private func calculateDateRange(for period: BudgetPeriod, startingFrom startDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current

        let dateOffset: (component: Calendar.Component, value: Int) = switch period {
        case .weekly:
            (.day, 7)
        case .monthly:
            (.month, 1)
        case .quarterly:
            (.month, 3)
        case .yearly:
            (.year, 1)
        }

        let endDate = calendar.date(
            byAdding: dateOffset.component,
            value: dateOffset.value,
            to: startDate
        ) ?? startDate
        return startDate...endDate
    }
}
