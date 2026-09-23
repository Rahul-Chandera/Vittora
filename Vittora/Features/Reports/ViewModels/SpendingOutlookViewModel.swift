import Foundation
import VittoraCore

/// Feeds both the month-end projection (M3.2.2) and what-if scenarios (M3.2.5).
///
/// One view model for both because they need the same thing: this month's spend
/// to date, and per-category monthly history. Fetching it twice would double the
/// work and let the two disagree about what a "typical" month is.
@Observable
@MainActor
final class SpendingOutlookViewModel {
    private let transactionRepository: any TransactionRepository
    private let categoryRepository: any CategoryRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    private let projectionEngine = SpendingProjectionEngine()
    private let whatIfEngine = WhatIfScenarioEngine()

    /// Whole months of history to draw on, excluding the month in progress.
    private static let lookbackMonths = 6

    var projection: SpendingProjectionEngine.Projection?
    var categories: [(id: UUID, name: String)] = []
    var selectedCategoryID: UUID?
    var reductionPercent: Decimal = 20
    var isLoading = false
    var error: String?

    /// Per-category monthly totals for the completed months only.
    private var monthlyByCategory: [UUID: [Decimal]] = [:]

    init(
        transactionRepository: any TransactionRepository,
        categoryRepository: any CategoryRepository,
        calendar: Calendar = Calendar(identifier: .gregorian),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var scenario: WhatIfScenarioEngine.Scenario? {
        guard let id = selectedCategoryID,
              let name = categories.first(where: { $0.id == id })?.name,
              let amounts = monthlyByCategory[id]
        else { return nil }
        return whatIfEngine.scenario(
            categoryName: name,
            monthlyAmounts: amounts,
            reductionPercent: reductionPercent
        )
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let now = nowProvider()
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start,
                  let windowStart = calendar.date(byAdding: .month, value: -Self.lookbackMonths, to: monthStart)
            else { isLoading = false; return }

            let transactions = try await transactionRepository.fetchAll(
                filter: TransactionFilter(dateRange: windowStart...now)
            )
            // Expenses only. Income and transfers are not spending, and counting
            // them would make both the projection and the baseline meaningless.
            let expenses = transactions.filter { $0.type == .expense }

            let spentSoFar = expenses
                .filter { $0.date >= monthStart }
                .reduce(Decimal(0)) { $0 + $1.amount }

            let elapsed = (calendar.dateComponents([.day], from: monthStart, to: now).day ?? 0) + 1
            let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

            // Completed months only. Including the month in progress would drag
            // every baseline down by however far through it we are.
            let completed = expenses.filter { $0.date < monthStart }
            var byCategoryMonth: [UUID: [Date: Decimal]] = [:]
            for transaction in completed {
                guard let categoryID = transaction.categoryID,
                      let bucket = self.calendar.dateInterval(of: .month, for: transaction.date)?.start
                else { continue }
                byCategoryMonth[categoryID, default: [:]][bucket, default: 0] += transaction.amount
            }
            // Oldest first, so a median is taken over a stable ordering.
            monthlyByCategory = byCategoryMonth.mapValues { months in
                months.sorted { $0.key < $1.key }.map(\.value)
            }

            let priorTotals: [Decimal] = Dictionary(
                grouping: completed,
                by: { self.calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            )
            .sorted { $0.key < $1.key }
            .map { $0.value.reduce(Decimal(0)) { $0 + $1.amount } }

            projection = projectionEngine.project(
                spentSoFar: spentSoFar,
                elapsedDays: elapsed,
                totalDays: totalDays,
                priorMonthTotals: priorTotals
            )

            let allCategories = try await categoryRepository.fetchAll()
            // Only categories with enough history to model are offered — a picker
            // full of options that produce nothing is worse than a short one.
            categories = allCategories
                .filter { (monthlyByCategory[$0.id]?.count ?? 0) >= WhatIfScenarioEngine.minimumBaselineMonths }
                .map { (id: $0.id, name: $0.name) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if selectedCategoryID == nil { selectedCategoryID = categories.first?.id }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
