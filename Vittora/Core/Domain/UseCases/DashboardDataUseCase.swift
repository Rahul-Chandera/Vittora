import Foundation

struct CategorySpend: Sendable {
    let category: CategoryEntity
    let amount: Decimal
}

struct DashboardData: Sendable {
    let todaySpending: Decimal
    let monthSpending: Decimal
    let monthIncome: Decimal
    let monthBudgetProgress: Double
    let recentTransactions: [TransactionEntity]
    let topCategories: [CategorySpend]
    let netWorth: Decimal
    let accountSummary: [AccountEntity]
    let upcomingRecurring: [RecurringRuleEntity]
}

struct DashboardDataUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let categoryRepository: any CategoryRepository
    let budgetRepository: any BudgetRepository
    let recurringRuleRepository: any RecurringRuleRepository

    func execute() async throws -> DashboardData {
        let now = Date.now
        let calendar = Calendar.current

        let startOfToday = calendar.startOfDay(for: now)
        let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        // Fetch only the current month's transactions instead of the full history.
        let monthFilter = TransactionFilter(dateRange: startOfMonth...now)

        async let allAccountsTask = accountRepository.fetchAll()
        async let monthTransactionsTask = transactionRepository.fetchAll(filter: monthFilter)
        async let allCategoriesTask = categoryRepository.fetchAll()
        async let activeBudgetsTask = budgetRepository.fetchActive()
        async let upcomingRulesTask = recurringRuleRepository.fetchActive()

        let (allAccounts, monthTransactions, allCategories, activeBudgets, activeRules) =
            try await (allAccountsTask, monthTransactionsTask, allCategoriesTask, activeBudgetsTask, upcomingRulesTask)

        let activeAccounts = allAccounts.filter { !$0.isArchived }

        // Net worth
        var totalAssets: Decimal = 0
        var totalLiabilities: Decimal = 0
        for account in activeAccounts {
            if account.type.isAsset {
                totalAssets += account.balance
            } else {
                totalLiabilities += account.balance
            }
        }
        let netWorth = totalAssets - totalLiabilities

        // Today's spending (subset of this month)
        let todaySpending = monthTransactions
            .filter { $0.type == .expense && $0.date >= startOfToday }
            .reduce(Decimal(0)) { $0 + $1.amount }

        // This month's spending and income
        let monthSpending = monthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let monthIncome = monthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }

        // Recent transactions (last 5 within this month)
        let recentTransactions = Array(
            monthTransactions.sorted { $0.date > $1.date }.prefix(5)
        )

        // Top categories by expense spend this month
        var categorySpend: [UUID: Decimal] = [:]
        for transaction in monthTransactions where transaction.type == .expense {
            if let catID = transaction.categoryID {
                categorySpend[catID, default: 0] += transaction.amount
            }
        }
        let topCategories = categorySpend
            .sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { (categoryID, amount) -> CategorySpend? in
                guard let category = allCategories.first(where: { $0.id == categoryID }) else {
                    return nil
                }
                return CategorySpend(category: category, amount: amount)
            }

        // Overall budget progress
        let totalBudget = activeBudgets.reduce(Decimal(0)) { $0 + $1.amount }
        let totalSpent = activeBudgets.reduce(Decimal(0)) { $0 + $1.spent }
        let monthBudgetProgress: Double
        if totalBudget > 0 {
            monthBudgetProgress = min(
                Double(truncating: (totalSpent / totalBudget) as NSDecimalNumber),
                1.0
            )
        } else {
            monthBudgetProgress = 0.0
        }

        // Upcoming recurring (next 3 by nextDate)
        let upcomingRecurring = Array(
            activeRules.sorted { $0.nextDate < $1.nextDate }.prefix(3)
        )

        return DashboardData(
            todaySpending: todaySpending,
            monthSpending: monthSpending,
            monthIncome: monthIncome,
            monthBudgetProgress: monthBudgetProgress,
            recentTransactions: recentTransactions,
            topCategories: topCategories,
            netWorth: netWorth,
            accountSummary: activeAccounts,
            upcomingRecurring: upcomingRecurring
        )
    }
}
