import Foundation
import VittoraCore

/// One thing worth telling the user about their own recent spending (M3.6.4 / M3.6.5).
///
/// Wraps both engines so a single surface can render them: they differ in what they
/// examine but not in what they are — an observation drawn from this user's records,
/// dismissible, and never an instruction.
struct SpendingInsight: Identifiable, Sendable, Equatable {
    nonisolated enum Kind: Sendable, Equatable {
        case anomaly(SpendingAnomaly)
        case budget(BudgetObservation)
    }

    nonisolated let id: String
    nonisolated let title: String
    nonisolated let detail: String
    nonisolated let kind: Kind
}

/// Builds the series both engines need and filters what the user has dismissed.
struct EvaluateSpendingInsightsUseCase: Sendable {
    /// How many completed periods to look back over. Four gives the engines their minimum
    /// three priors plus the one being judged.
    nonisolated static let lookbackMonths = 4

    /// At most three cards. This sits above the report list, and a user with several
    /// unused budgets would otherwise push the reports off screen with near-identical
    /// cards — observed on eight months of demo data, where three "nothing spent against"
    /// cards filled the entire first screen. The ranking already puts the urgent ones
    /// first, so a cap drops the least useful.
    nonisolated static let maximumInsights = 3

    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let budgetRepository: any BudgetRepository
    let dismissalStore: any SpendingInsightDismissalStoring
    let calendar: Calendar

    nonisolated init(
        transactionRepository: any TransactionRepository,
        categoryRepository: any CategoryRepository,
        budgetRepository: any BudgetRepository,
        dismissalStore: any SpendingInsightDismissalStoring,
        calendar: Calendar = .current
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.budgetRepository = budgetRepository
        self.dismissalStore = dismissalStore
        self.calendar = calendar
    }

    func execute(now: Date = .now, currencyCode: String = CurrencyDefaults.code) async throws -> [SpendingInsight] {
        let period = Self.periodKey(for: now, calendar: calendar)
        guard let windowStart = calendar.date(
            byAdding: .month,
            value: -Self.lookbackMonths,
            to: Self.startOfMonth(now, calendar: calendar)
        ) else { return [] }

        let transactions = try await transactionRepository.fetchAll(
            filter: TransactionFilter(dateRange: windowStart...now, types: Set([.expense]))
        )
        let categories = try await categoryRepository.fetchAll()
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        // Bucket by category and month. The current month is the one being judged; the
        // completed months before it are the norm.
        var byCategory: [UUID: [String: Decimal]] = [:]
        for transaction in transactions {
            guard let categoryID = transaction.categoryID else { continue }
            let key = Self.periodKey(for: transaction.date, calendar: calendar)
            byCategory[categoryID, default: [:]][key, default: 0] += transaction.amount
        }

        let priorKeys = Self.priorPeriodKeys(before: now, count: Self.lookbackMonths, calendar: calendar)

        let anomalySeries = byCategory.compactMap { categoryID, months -> SpendingAnomalyEngine.CategorySeries? in
            guard let category = categoriesByID[categoryID] else { return nil }
            return SpendingAnomalyEngine.CategorySeries(
                categoryID: categoryID,
                categoryName: category.displayName,
                priorAmounts: priorKeys.map { months[$0] ?? 0 },
                currentAmount: months[period] ?? 0
            )
        }

        let budgets = try await budgetRepository.fetchActive()
        let budgetSeries = budgets.compactMap { budget -> BudgetOptimisationEngine.BudgetSeries? in
            guard let categoryID = budget.categoryID,
                  let category = categoriesByID[categoryID]
            else { return nil }
            let months = byCategory[categoryID] ?? [:]
            return BudgetOptimisationEngine.BudgetSeries(
                budgetID: budget.id,
                categoryName: category.displayName,
                limit: budget.amount,
                priorSpend: priorKeys.map { months[$0] ?? 0 }
            )
        }

        let insights = SpendingAnomalyEngine.evaluate(anomalySeries).map {
            Self.insight(from: $0, currencyCode: currencyCode)
        } + BudgetOptimisationEngine.evaluate(budgetSeries).map {
            Self.insight(from: $0, currencyCode: currencyCode)
        }

        return Array(
            insights
                .filter { !dismissalStore.isDismissed(insightID: $0.id, period: period) }
                .prefix(Self.maximumInsights)
        )
    }

    func dismiss(_ insight: SpendingInsight, now: Date = .now) {
        dismissalStore.dismiss(
            insightID: insight.id,
            period: Self.periodKey(for: now, calendar: calendar)
        )
    }

    // MARK: - Presentation

    nonisolated private static func insight(from anomaly: SpendingAnomaly, currencyCode: String) -> SpendingInsight {
        SpendingInsight(
            id: "anomaly-\(anomaly.categoryID.uuidString)",
            title: String(localized: "\(anomaly.categoryName) is well above your usual"),
            detail: String(localized: "You've spent \(anomaly.currentAmount.formatted(.currency(code: currencyCode))) this month. Your usual is about \(anomaly.typicalAmount.formatted(.currency(code: currencyCode))), based on the last \(anomaly.priorPeriodCount) months."),
            kind: .anomaly(anomaly)
        )
    }

    nonisolated private static func insight(from observation: BudgetObservation, currencyCode: String) -> SpendingInsight {
        let limit = observation.limit.formatted(.currency(code: currencyCode))
        let typical = observation.typicalSpend.formatted(.currency(code: currencyCode))
        switch observation.kind {
        case .unused:
            return SpendingInsight(
                id: "budget-\(observation.budgetID.uuidString)",
                title: String(localized: "Nothing spent against \(observation.categoryName)"),
                detail: String(localized: "This \(limit) budget has had no spending for \(observation.periodCount) months."),
                kind: .budget(observation)
            )
        case .consistentlyOverSpent:
            return SpendingInsight(
                id: "budget-\(observation.budgetID.uuidString)",
                title: String(localized: "\(observation.categoryName) goes over every month"),
                detail: String(localized: "The budget is \(limit) and you typically spend \(typical). That's \(observation.periodCount) months running."),
                kind: .budget(observation)
            )
        case .consistentlyUnderSpent:
            return SpendingInsight(
                id: "budget-\(observation.budgetID.uuidString)",
                title: String(localized: "\(observation.categoryName) has room to spare"),
                detail: String(localized: "The budget is \(limit) and you typically spend \(typical), for \(observation.periodCount) months now."),
                kind: .budget(observation)
            )
        }
    }

    // MARK: - Periods

    nonisolated static func periodKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    nonisolated static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// Completed months before `date`, oldest first — never the month in progress, which
    /// would drag every average down simply because it is not finished.
    nonisolated static func priorPeriodKeys(before date: Date, count: Int, calendar: Calendar) -> [String] {
        (1...max(1, count)).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: date)
                .map { periodKey(for: $0, calendar: calendar) }
        }
    }
}
