import Foundation
import VittoraCore

struct CategoryBreakdown: Sendable, Identifiable {
    nonisolated var id: UUID { category.id }
    nonisolated let category: CategoryEntity
    nonisolated let amount: Decimal
    nonisolated let percentage: Double
    nonisolated let transactionCount: Int
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

        let categoryByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Spending with no category, or whose category has since been deleted,
        // is gathered here rather than dropped.
        //
        // Both used to vanish: the loop skipped a nil `categoryID`, so the
        // seeded $200 "Settlement: Moving costs" was simply absent, and the
        // report's percentages were of CATEGORISED spending while the
        // Dashboard's "Spent" covered everything — Rent read 67.3% here and
        // 62.7% on the Custom Report for the same $1,850, with nothing on
        // screen to explain the gap.
        //
        // The deleted-category case was worse than absent: the amount still
        // counted toward `total` but had no row, so the listed percentages did
        // not even sum to 100%.
        //
        // Custom Report and the 50/30/20 report both surface uncategorised
        // spending already; this brings the third report into line.
        var categoryAmounts: [UUID: (amount: Decimal, count: Int)] = [:]
        var uncategorised = (amount: Decimal(0), count: 0)
        for transaction in transactions {
            guard let catID = transaction.categoryID, categoryByID[catID] != nil else {
                uncategorised.amount += transaction.amount
                uncategorised.count += 1
                continue
            }
            var entry = categoryAmounts[catID] ?? (amount: Decimal(0), count: 0)
            entry.amount += transaction.amount
            entry.count += 1
            categoryAmounts[catID] = entry
        }

        let total = categoryAmounts.values.reduce(Decimal(0)) { $0 + $1.amount }
            + uncategorised.amount

        var breakdowns = categoryAmounts
            .compactMap { (categoryID, data) -> CategoryBreakdown? in
                guard let category = categoryByID[categoryID] else {
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
        if uncategorised.amount > 0 {
            let percentage = total > 0
                ? Double(truncating: (uncategorised.amount / total * 100) as NSDecimalNumber)
                : 0.0
            breakdowns.append(
                CategoryBreakdown(
                    category: Self.uncategorisedCategory(type: type),
                    amount: uncategorised.amount,
                    percentage: percentage,
                    transactionCount: uncategorised.count
                )
            )
        }

        breakdowns.sort { $0.amount > $1.amount }

        return Array(breakdowns.prefix(Self.maxBreakdowns))
    }

    /// A stand-in so uncategorised spending can appear as a row. The id is
    /// fixed rather than fresh per call so the row keeps its identity across
    /// reloads and does not re-animate.
    private static func uncategorisedCategory(type: TransactionType) -> CategoryEntity {
        CategoryEntity(
            id: uncategorisedID,
            name: String(localized: "Uncategorized"),
            icon: "questionmark.circle",
            type: type == .income ? .income : .expense
        )
    }

    private static let uncategorisedID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!

    private static func defaultDateRange(calendar: Calendar) -> ClosedRange<Date> {
        let now = Date.now
        let start = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        return start...now
    }
}
