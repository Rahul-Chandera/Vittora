import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class AssignMoneyViewModel {
    private let reportingTransactions: any TransactionRepository
    private let budgetRepository: any BudgetRepository
    private let categoryRepository: any CategoryRepository

    private(set) var plan: AssignMoneyPlan?
    private var budgets: [BudgetEntity] = []
    var error: String?

    init(
        reportingTransactions: any TransactionRepository,
        budgetRepository: any BudgetRepository,
        categoryRepository: any CategoryRepository
    ) {
        self.reportingTransactions = reportingTransactions
        self.budgetRepository = budgetRepository
        self.categoryRepository = categoryRepository
    }

    func load(now: Date = .now, calendar: Calendar = .current) async {
        do {
            let month = calendar.dateInterval(of: .month, for: now)
            let range = (month?.start ?? now)...now
            let transactions = try await reportingTransactions.fetchAll(filter: TransactionFilter(dateRange: range))
            budgets = try await budgetRepository.fetchActive()
            let categories = try await categoryRepository.fetchAll()
            plan = AssignMoneyPlanner.plan(transactions: transactions, budgets: budgets, categories: categories)
        } catch {
            self.error = String(localized: "Couldn't load your budgets right now.")
        }
    }

    /// Sets the category's monthly budget to `amount`, creating it if needed.
    func assign(_ amount: Decimal, to categoryID: UUID, now: Date = .now, calendar: Calendar = .current) async {
        guard amount > 0 else { return }
        do {
            if var existing = budgets.first(where: { $0.categoryID == categoryID }) {
                guard existing.period == .monthly, existing.amount != amount else { return }
                existing.amount = amount
                existing.rollover = true
                try await UpdateBudgetUseCase(budgetRepository: budgetRepository).execute(existing)
            } else {
                let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
                try await CreateBudgetUseCase(budgetRepository: budgetRepository).execute(
                    amount: amount, period: .monthly, categoryID: categoryID, rollover: true, startDate: start
                )
            }
            await load(now: now, calendar: calendar)
        } catch {
            self.error = error.userFacingMessage(fallback: String(localized: "Couldn't save that amount. Try again."))
        }
    }
}
