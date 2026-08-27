import Foundation
import VittoraCore

struct CashFlowForecastUseCase: Sendable {
    let accountRepository: any AccountRepository
    let transactionRepository: any TransactionRepository
    let recurringRuleRepository: any RecurringRuleRepository
    let categoryRepository: any CategoryRepository
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date

    nonisolated init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository,
        recurringRuleRepository: any RecurringRuleRepository,
        categoryRepository: any CategoryRepository,
        calendar: Calendar = Calendar(identifier: .gregorian),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.recurringRuleRepository = recurringRuleRepository
        self.categoryRepository = categoryRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func execute(
        dayCount: Int = CashFlowForecastMath.defaultDayCount,
        trailingHistoryDays: Int = CashFlowForecastMath.defaultTrailingHistoryDays
    ) async throws -> CashFlowForecastResult {
        let todayStart = calendar.startOfDay(for: nowProvider())

        let allAccounts = try await accountRepository.fetchAll().filter { !$0.isArchived }

        // Project one currency, not a mixture. This use case had its own
        // netWorth(of:) that added every balance together regardless of
        // currency, so an INR account was projected under the display
        // currency's symbol — the same relabelling fixed in
        // CalculateNetWorthUseCase, in a second place.
        //
        // The dominant currency wins, matching the Net Worth report's
        // composition bar: a projection is a single series, and there is
        // nothing to convert the others with.
        let summary = NetWorthSummary.build(from: allAccounts)
        let projectedCurrency = summary.byCurrency.first?.currencyCode
        let accounts = projectedCurrency.map { code in
            allAccounts.filter { $0.currencyCode == code }
        } ?? allAccounts
        let startingBalance = netWorth(of: accounts)

        guard let lookbackStart = calendar.date(
            byAdding: .day,
            value: -trailingHistoryDays,
            to: todayStart
        ) else {
            return CashFlowForecastMath.project(
                startingBalance: startingBalance,
                averageDailyDiscretionarySpend: 0,
                scheduledDeltas: [],
                todayStart: todayStart,
                dayCount: dayCount,
                calendar: calendar
            )
        }

        // Fetch through todayStart; keep only transactions strictly before today
        // so the discretionary average is over complete calendar days.
        let historyFilter = TransactionFilter(dateRange: lookbackStart...todayStart)
        let historyTransactions = try await transactionRepository.fetchAll(filter: historyFilter)
            .filter { $0.date < todayStart }

        let earliestDay = historyTransactions.map { calendar.startOfDay(for: $0.date) }.min()
        let historyDays = CashFlowForecastMath.historyDayCount(
            todayStart: todayStart,
            earliestTransactionDay: earliestDay,
            trailingHistoryDays: trailingHistoryDays,
            calendar: calendar
        )
        let windowStart = CashFlowForecastMath.historyWindowStart(
            todayStart: todayStart,
            earliestTransactionDay: earliestDay,
            trailingHistoryDays: trailingHistoryDays,
            calendar: calendar
        )

        let discretionaryTotal: Decimal = {
            guard let windowStart else { return 0 }
            return historyTransactions
                .filter { tx in
                    tx.type == .expense
                        && tx.recurringRuleID == nil
                        && tx.date >= windowStart
                        && tx.date < todayStart
                }
                .reduce(Decimal(0)) { $0 + $1.amount }
        }()

        let averageDiscretionary = CashFlowForecastMath.averageDailyDiscretionarySpend(
            nonRecurringExpenseTotal: discretionaryTotal,
            historyDayCount: historyDays
        )

        let categories = try await categoryRepository.fetchAll()
        let categoryTypeByID = Dictionary(categories.map { ($0.id, $0.type) }, uniquingKeysWith: { first, _ in first })
        let activeRules = try await recurringRuleRepository.fetchActive()

        guard let forecastStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
              let forecastEndExclusive = calendar.date(
                byAdding: .day,
                value: dayCount + 1,
                to: todayStart
              ) else {
            return CashFlowForecastMath.project(
                startingBalance: startingBalance,
                averageDailyDiscretionarySpend: averageDiscretionary,
                scheduledDeltas: [],
                todayStart: todayStart,
                dayCount: dayCount,
                historyDayCount: historyDays,
                discretionaryExpenseTotal: discretionaryTotal,
                calendar: calendar
            )
        }

        // Occurrences from tomorrow through day `dayCount` (today's recurring
        // posts are already reflected in current balances).
        let forecastInterval = forecastStart..<forecastEndExclusive
        var scheduledDeltas: [CashFlowForecastScheduledDelta] = []

        for rule in activeRules {
            guard rule.isActive, rule.templateAccountID != nil else { continue }
            if let endDate = rule.endDate, endDate < todayStart { continue }

            let sign: Decimal = {
                guard let categoryID = rule.templateCategoryID,
                      let type = categoryTypeByID[categoryID] else {
                    return -1 // Uncategorized recurring posts as expense today.
                }
                return type == .income ? 1 : -1
            }()

            let dates = RecurrenceDateMath.occurrences(
                startingAt: rule.nextDate,
                frequency: rule.frequency,
                in: forecastInterval,
                endDate: rule.endDate,
                calendar: calendar
            )
            for occurrence in dates {
                scheduledDeltas.append(
                    CashFlowForecastScheduledDelta(
                        day: calendar.startOfDay(for: occurrence),
                        amount: sign * rule.templateAmount
                    )
                )
            }
        }

        return CashFlowForecastMath.project(
            startingBalance: startingBalance,
            averageDailyDiscretionarySpend: averageDiscretionary,
            scheduledDeltas: scheduledDeltas,
            todayStart: todayStart,
            dayCount: dayCount,
            historyDayCount: historyDays,
            discretionaryExpenseTotal: discretionaryTotal,
            calendar: calendar
        )
    }

    /// The currency `execute()` projects in — the dominant one by net worth.
    ///
    /// Exposed so the view can label the projection with the money's own
    /// currency instead of the display default, which is what made an INR
    /// balance read as dollars here.
    func projectedCurrencyCode() async throws -> String? {
        let accounts = try await accountRepository.fetchAll().filter { !$0.isArchived }
        return NetWorthSummary.build(from: accounts).byCurrency.first?.currencyCode
    }

    nonisolated private func netWorth(of accounts: [AccountEntity]) -> Decimal {
        var assets: Decimal = 0
        var liabilities: Decimal = 0
        for account in accounts {
            if account.type.isAsset {
                assets += account.balance
            } else {
                liabilities += account.balance
            }
        }
        return assets - liabilities
    }
}
