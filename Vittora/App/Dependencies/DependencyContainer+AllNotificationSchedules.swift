import Foundation
import VittoraCore

extension DependencyContainer {
    /// Rebuilds all local notification schedules according to current preferences.
    @MainActor
    func refreshAllNotificationSchedules() async {
        await refreshBudgetThresholdAlerts()
        await refreshCreditCardDueReminders()
        await refreshRecurringAndDebtReminders()
    }
}
