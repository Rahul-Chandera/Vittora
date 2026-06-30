import Foundation
import VittoraCore

struct CashFlowMonth: Sendable, Identifiable {
    nonisolated var id: Date { month }
    nonisolated let month: Date
    nonisolated let actualIncome: Decimal?
    nonisolated let actualExpense: Decimal?
    nonisolated let projectedIncome: Decimal?
    nonisolated let projectedExpense: Decimal?
    nonisolated let recurringExpense: Decimal

    nonisolated var isProjected: Bool {
        actualIncome == nil && actualExpense == nil
    }

    nonisolated var displayIncome: Decimal {
        actualIncome ?? projectedIncome ?? 0
    }

    nonisolated var displayExpense: Decimal {
        actualExpense ?? projectedExpense ?? 0
    }

    nonisolated var net: Decimal {
        displayIncome - displayExpense
    }
}

struct CashFlowProjectionResult: Sendable {
    nonisolated let months: [CashFlowMonth]
    nonisolated let averageDiscretionaryExpense: Decimal
    nonisolated let averageIncome: Decimal
}

struct CashFlowProjectionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let recurringRuleRepository: any RecurringRuleRepository
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date

    nonisolated init(
        transactionRepository: any TransactionRepository,
        recurringRuleRepository: any RecurringRuleRepository,
        calendar: Calendar = Calendar(identifier: .gregorian),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRuleRepository = recurringRuleRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func execute(
        historyMonthCount: Int = 12,
        projectionMonthCount: Int = 6
    ) async throws -> CashFlowProjectionResult {
        let now = nowProvider()
        let currentMonthStart = monthStart(for: now)
        let historyStart = calendar.date(
            byAdding: .month,
            value: -(historyMonthCount - 1),
            to: currentMonthStart
        ) ?? currentMonthStart

        let filter = TransactionFilter(dateRange: historyStart...now)
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        let activeRules = try await recurringRuleRepository.fetchActive()

        var historicalDiscretionary: [Decimal] = []
        var historicalIncome: [Decimal] = []
        var actualMonths: [CashFlowMonth] = []

        for offset in 0..<historyMonthCount {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: historyStart),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let monthTransactions = transactions.filter { $0.date >= monthStart && $0.date < monthEnd }
            let income = monthTransactions
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let expense = monthTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let recurringFromTransactions = monthTransactions
                .filter { $0.type == .expense && $0.recurringRuleID != nil }
                .reduce(Decimal(0)) { $0 + $1.amount }

            if income > 0 || expense > 0 {
                historicalIncome.append(income)
                historicalDiscretionary.append(max(0, expense - recurringFromTransactions))
            }

            actualMonths.append(
                CashFlowMonth(
                    month: monthStart,
                    actualIncome: income,
                    actualExpense: expense,
                    projectedIncome: nil,
                    projectedExpense: nil,
                    recurringExpense: recurringFromTransactions
                )
            )
        }

        let averageIncome = average(of: historicalIncome)
        let averageDiscretionary = average(of: historicalDiscretionary)

        var projectedMonths: [CashFlowMonth] = []
        for offset in 1...projectionMonthCount {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let recurringExpense = RecurrenceDateMath.totalAmount(
                for: activeRules,
                in: monthStart..<monthEnd,
                calendar: calendar
            )
            let projectedExpense = recurringExpense + averageDiscretionary

            projectedMonths.append(
                CashFlowMonth(
                    month: monthStart,
                    actualIncome: nil,
                    actualExpense: nil,
                    projectedIncome: averageIncome,
                    projectedExpense: projectedExpense,
                    recurringExpense: recurringExpense
                )
            )
        }

        return CashFlowProjectionResult(
            months: actualMonths + projectedMonths,
            averageDiscretionaryExpense: averageDiscretionary,
            averageIncome: averageIncome
        )
    }

    nonisolated private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    nonisolated private func average(of values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(Decimal(0), +)
        return total / Decimal(values.count)
    }
}
