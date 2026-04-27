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
    private static let maxTrendPoints = 370

    func execute(
        dateRange: ClosedRange<Date>? = nil,
        grouping: TrendGrouping = .daily,
        type: TransactionType = .expense
    ) async throws -> [TrendDataPoint] {
        let calendar = Calendar.current
        let boundedRange = dateRange ?? Self.defaultDateRange(calendar: calendar)
        let effectiveGrouping = Self.effectiveGrouping(
            requestedGrouping: grouping,
            dateRange: boundedRange,
            calendar: calendar
        )
        let filter = TransactionFilter(dateRange: boundedRange, types: Set([type]))
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        var grouped: [Date: Decimal] = [:]

        for transaction in transactions {
            let periodStart: Date
            switch effectiveGrouping {
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

        let points = grouped
            .map { TrendDataPoint(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }

        return Array(points.suffix(Self.maxTrendPoints))
    }

    private static func defaultDateRange(calendar: Calendar) -> ClosedRange<Date> {
        let now = Date.now
        let start = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        return start...now
    }

    private static func effectiveGrouping(
        requestedGrouping: TrendGrouping,
        dateRange: ClosedRange<Date>,
        calendar: Calendar
    ) -> TrendGrouping {
        let dayCount = calendar.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 0
        let minimumGrouping: TrendGrouping
        if dayCount <= 90 {
            minimumGrouping = .daily
        } else if dayCount <= 365 {
            minimumGrouping = .weekly
        } else {
            minimumGrouping = .monthly
        }

        return requestedGrouping.rank >= minimumGrouping.rank ? requestedGrouping : minimumGrouping
    }
}

private extension TrendGrouping {
    var rank: Int {
        switch self {
        case .daily: return 0
        case .weekly: return 1
        case .monthly: return 2
        }
    }
}
