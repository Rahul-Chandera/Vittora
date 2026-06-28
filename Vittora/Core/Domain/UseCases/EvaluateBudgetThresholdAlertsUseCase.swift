import Foundation

struct EvaluateBudgetThresholdAlertsUseCase: Sendable {
    private static let notificationsEnabledKey = AppUserDefaults.StandardKey.notificationsEnabled
    private static let notifyBudgetAlertsKey = AppUserDefaults.StandardKey.notifyBudgetAlerts

    let budgetFetcher: any ActiveBudgetFetching
    let checkThresholdUseCase: CheckBudgetThresholdUseCase
    let alertStore: any BudgetThresholdAlertStoring
    let notificationService: any NotificationServiceProtocol
    let userDefaults: UserDefaults

    init(
        budgetFetcher: any ActiveBudgetFetching,
        checkThresholdUseCase: CheckBudgetThresholdUseCase = CheckBudgetThresholdUseCase(),
        alertStore: any BudgetThresholdAlertStoring,
        notificationService: any NotificationServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.budgetFetcher = budgetFetcher
        self.checkThresholdUseCase = checkThresholdUseCase
        self.alertStore = alertStore
        self.notificationService = notificationService
        self.userDefaults = userDefaults
    }

    func execute() async throws {
        guard isBudgetAlertsEnabled else { return }

        let budgets = try await budgetFetcher.fetchActiveBudgetsWithSpent()
        for budget in budgets {
            let periodKey = BudgetThresholdAlertStore.periodKey(for: budget)
            let previouslyFired = alertStore.firedLevels(forPeriodKey: periodKey)
            let newLevels = checkThresholdUseCase.newlyCrossedThresholds(
                for: budget,
                previouslyFired: previouslyFired
            )
            for level in newLevels {
                try await notificationService.schedule(
                    makeNotificationRequest(budget: budget, level: level, periodKey: periodKey)
                )
                alertStore.markFired(level, forPeriodKey: periodKey)
            }
        }
    }

    private var isBudgetAlertsEnabled: Bool {
        userDefaults.bool(forKey: Self.notificationsEnabledKey)
            && (userDefaults.object(forKey: Self.notifyBudgetAlertsKey) as? Bool ?? true)
    }

    private func makeNotificationRequest(
        budget: BudgetEntity,
        level: BudgetThresholdLevel,
        periodKey: String
    ) -> ScheduledNotificationRequest {
        ScheduledNotificationRequest(
            identifier: "budget-threshold-\(periodKey)-\(level.rawValue)",
            title: String(localized: "Budget Alert"),
            body: String(
                localized: "You've reached \(level.rawValue)% of your budget."
            ),
            fireDate: Date.now.addingTimeInterval(1),
            category: .budgetAlert,
            deepLink: VittoraNotificationDeepLink(
                destination: .budgetDetail,
                entityID: budget.id
            )
        )
    }
}
