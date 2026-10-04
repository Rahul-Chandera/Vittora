import Foundation
import VittoraCore

extension DependencyContainer {
    /// Rebuilds all local notification schedules according to current preferences.
    @MainActor
    func refreshAllNotificationSchedules() async {
        await refreshBudgetThresholdAlerts()
        await refreshCreditCardDueReminders()
        await refreshRecurringAndDebtReminders()
        await refreshInvestmentMaturityReminders()
    }

    /// Also called after any edit to a tracked investment, because the use case reconciles:
    /// clearing a maturity date or switching the reminder off must cancel the pending
    /// notification, not merely stop scheduling new ones.
    @MainActor
    func refreshInvestmentMaturityReminders() async {
        try? await scheduleInvestmentMaturityRemindersUseCase.execute()
    }
}
