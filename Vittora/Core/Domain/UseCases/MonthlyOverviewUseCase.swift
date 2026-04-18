import Foundation

struct MonthlyData: Sendable, Identifiable {
    var id: Date { month }
    let month: Date
    let income: Decimal
    let expense: Decimal
    var net: Decimal { income - expense }
}

struct MonthlyOverviewUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    func execute(monthCount: Int = 12) async throws -> [MonthlyData] {
        let calendar = Calendar.current
        let now = Date.now
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        // Bound the fetch to the requested window instead of loading all history.
        let windowStart = calendar.date(byAdding: .month, value: -(monthCount - 1), to: currentMonthStart) ?? currentMonthStart
        let filter = TransactionFilter(dateRange: windowStart...now)
        let allTransactions = try await transactionRepository.fetchAll(filter: filter)

        var results: [MonthlyData] = []
        for i in stride(from: monthCount - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: currentMonthStart),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let monthTransactions = allTransactions.filter {
                $0.date >= monthStart && $0.date < monthEnd
            }

            let income = monthTransactions
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }

            let expense = monthTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }

            results.append(MonthlyData(month: monthStart, income: income, expense: expense))
        }

        return results
    }
}
