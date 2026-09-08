import Foundation
import VittoraCore

struct MonthlyData: Sendable, Identifiable {
    nonisolated var id: Date { month }
    nonisolated let month: Date
    nonisolated let income: Decimal
    nonisolated let expense: Decimal
    nonisolated var net: Decimal { income - expense }
}

struct MonthlyOverviewUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    /// Rolling window ending with the current month. Used by Monthly Overview.
    func execute(monthCount: Int = 12) async throws -> [MonthlyData] {
        let calendar = Calendar.current
        let now = Date.now
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        // Bound the fetch to the requested window instead of loading all history.
        let windowStart = calendar.date(byAdding: .month, value: -(monthCount - 1), to: currentMonthStart) ?? currentMonthStart
        let months = (0..<monthCount).compactMap {
            calendar.date(byAdding: .month, value: -(monthCount - 1 - $0), to: currentMonthStart)
        }
        return try await buckets(months: months, fetchFrom: windowStart, to: now)
    }

    /// One calendar year, January through December.
    ///
    /// Annual Summary needs this: it used to call `execute(monthCount:)`, which
    /// is anchored to `Date.now`, so every year in the picker rendered the same
    /// trailing-12-month data and switching years changed nothing.
    func execute(year: Int) async throws -> [MonthlyData] {
        let calendar = Calendar.current
        guard let january = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextJanuary = calendar.date(byAdding: .year, value: 1, to: january) else {
            return []
        }
        let months = (0..<12).compactMap {
            calendar.date(byAdding: .month, value: $0, to: january)
        }
        return try await buckets(months: months, fetchFrom: january, to: nextJanuary)
    }

    /// Sums income and expense into each month. The fetch range is inclusive at
    /// both ends, so it can pull a little either side; the per-month
    /// `>= start && < end` test is what actually assigns a transaction.
    private func buckets(months: [Date], fetchFrom: Date, to: Date) async throws -> [MonthlyData] {
        let calendar = Calendar.current
        let filter = TransactionFilter(dateRange: fetchFrom...to)
        let allTransactions = try await transactionRepository.fetchAll(filter: filter)

        return months.compactMap { monthStart in
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return nil
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
            return MonthlyData(month: monthStart, income: income, expense: expense)
        }
    }
}
