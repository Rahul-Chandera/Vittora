import Foundation
import VittoraCore

/// Gathers the three inputs the health score needs (M3.2.4).
///
/// The engine is pure and takes everything as arguments; this is the only part
/// that touches a store, so the arithmetic stays testable on its own.
@Observable
@MainActor
final class FinancialHealthScoreViewModel {
    private let transactionRepository: any TransactionRepository
    private let budgetRepository: any BudgetRepository
    private let debtRepository: any DebtRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private let engine = FinancialHealthScoreEngine()

    var result: FinancialHealthScoreEngine.Result?
    var isLoading = false
    var error: String?

    init(
        transactionRepository: any TransactionRepository,
        budgetRepository: any BudgetRepository,
        debtRepository: any DebtRepository,
        calendar: Calendar = Calendar(identifier: .gregorian),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
        self.debtRepository = debtRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let now = nowProvider()
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

            let transactions = try await transactionRepository.fetchAll(filter: nil)
            let thisMonth = transactions.filter { $0.date >= monthStart && $0.date <= now }

            // Transfers are excluded from both sides: moving money between your
            // own accounts is neither income nor spending, and counting it would
            // inflate the savings rate for anyone who sweeps to savings.
            let income = thisMonth
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let expenses = thisMonth
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }

            let budgets = try await budgetRepository.fetchActive()

            // Only what the user BORROWED counts against them. Money they lent is
            // an asset, and netting the two would let a large loan out mask
            // real debt.
            let debts = try await debtRepository.fetchOutstanding()
            let owed = debts
                .filter { $0.direction == .borrowed }
                .reduce(Decimal(0)) { $0 + max(0, $1.amount - $1.settledAmount) }

            result = engine.score(
                .init(
                    monthlyIncome: income,
                    monthlyExpenses: expenses,
                    budgets: budgets,
                    outstandingDebt: owed
                )
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
