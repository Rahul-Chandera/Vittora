import Foundation

enum TrendGrouping: String, CaseIterable, Sendable, Hashable {
    case daily, weekly, monthly

    var displayName: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }
}

struct TrendDataPoint: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
}

struct SpendingTrendsUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    func execute(
        dateRange: ClosedRange<Date>? = nil,
        grouping: TrendGrouping = .daily,
        type: TransactionType = .expense
    ) async throws -> [TrendDataPoint] {
        let filter = TransactionFilter(dateRange: dateRange, types: Set([type]))
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        let calendar = Calendar.current
        var grouped: [Date: Decimal] = [:]

        for transaction in transactions {
            let periodStart: Date
            switch grouping {
            case .daily:
                periodStart = calendar.startOfDay(for: transaction.date)
            case .weekly:
                let components = calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear], from: transaction.date
                )
                periodStart = calendar.date(from: components)
                    ?? calendar.startOfDay(for: transaction.date)
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: transaction.date)
                periodStart = calendar.date(from: components)
                    ?? calendar.startOfDay(for: transaction.date)
            }
            var current = grouped[periodStart] ?? Decimal(0)
            current += transaction.amount
            grouped[periodStart] = current
        }

        return grouped
            .map { TrendDataPoint(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
