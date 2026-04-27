import Foundation

struct MonthComparison: Sendable {
    let currentMonthSpending: Decimal
    let lastMonthSpending: Decimal
    let currentMonthIncome: Decimal
    let lastMonthIncome: Decimal

    /// Positive = spending increased, negative = spending decreased
    var spendingChangePercent: Double {
        guard lastMonthSpending > 0 else { return currentMonthSpending > 0 ? 100.0 : 0.0 }
        let change = currentMonthSpending - lastMonthSpending
        return Double(truncating: (change / lastMonthSpending * 100) as NSDecimalNumber)
    }

    /// Positive = income increased, negative = income decreased
    var incomeChangePercent: Double {
        guard lastMonthIncome > 0 else { return currentMonthIncome > 0 ? 100.0 : 0.0 }
        let change = currentMonthIncome - lastMonthIncome
        return Double(truncating: (change / lastMonthIncome * 100) as NSDecimalNumber)
    }

    /// Savings rate = (income - spending) / income, clamped to [0, 1]
    var savingsRate: Double {
        guard currentMonthIncome > 0 else { return 0.0 }
        let savings = currentMonthIncome - currentMonthSpending
        let rate = Double(truncating: (savings / currentMonthIncome) as NSDecimalNumber)
        return max(0.0, min(1.0, rate))
    }
}

struct MonthComparisonUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    func execute() async throws -> MonthComparison {
        let now = Date.now
        let calendar = Calendar.current

        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        let lastMonthStart = calendar.date(
            byAdding: .month, value: -1, to: currentMonthStart
        ) ?? now

        let filter = TransactionFilter(dateRange: lastMonthStart...now)
        let twoMonthTransactions = try await transactionRepository.fetchAll(filter: filter)

        let currentMonthTransactions = twoMonthTransactions.filter { $0.date >= currentMonthStart }
        let lastMonthTransactions = twoMonthTransactions.filter {
            $0.date >= lastMonthStart && $0.date < currentMonthStart
        }

        let currentSpending = currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let lastSpending = lastMonthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let currentIncome = currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let lastIncome = lastMonthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }

        return MonthComparison(
            currentMonthSpending: currentSpending,
            lastMonthSpending: lastSpending,
            currentMonthIncome: currentIncome,
            lastMonthIncome: lastIncome
        )
    }
}
