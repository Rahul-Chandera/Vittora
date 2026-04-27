import Foundation

struct CategoryBreakdown: Sendable, Identifiable {
    var id: UUID { category.id }
    let category: CategoryEntity
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
}

struct CategoryBreakdownUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    private static let maxBreakdowns = 25

    func execute(
        dateRange: ClosedRange<Date>? = nil,
        type: TransactionType = .expense
    ) async throws -> [CategoryBreakdown] {
        let calendar = Calendar.current
        let boundedRange = dateRange ?? Self.defaultDateRange(calendar: calendar)
        let filter = TransactionFilter(dateRange: boundedRange, types: Set([type]))

        async let transactionsTask = transactionRepository.fetchAll(filter: filter)
        async let categoriesTask = categoryRepository.fetchAll()

        let (transactions, categories) = try await (transactionsTask, categoriesTask)

        var categoryAmounts: [UUID: (amount: Decimal, count: Int)] = [:]
        for transaction in transactions {
            guard let catID = transaction.categoryID else { continue }
            var entry = categoryAmounts[catID] ?? (amount: Decimal(0), count: 0)
            entry.amount += transaction.amount
            entry.count += 1
            categoryAmounts[catID] = entry
        }

        let total = categoryAmounts.values.reduce(Decimal(0)) { $0 + $1.amount }

        let breakdowns = categoryAmounts
            .compactMap { (categoryID, data) -> CategoryBreakdown? in
                guard let category = categories.first(where: { $0.id == categoryID }) else {
                    return nil
                }
                let percentage = total > 0
                    ? Double(truncating: (data.amount / total * 100) as NSDecimalNumber)
                    : 0.0
                return CategoryBreakdown(
                    category: category,
                    amount: data.amount,
                    percentage: percentage,
                    transactionCount: data.count
                )
            }
            .sorted { $0.amount > $1.amount }

        return Array(breakdowns.prefix(Self.maxBreakdowns))
    }

    private static func defaultDateRange(calendar: Calendar) -> ClosedRange<Date> {
        let now = Date.now
        let start = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        return start...now
    }
}
