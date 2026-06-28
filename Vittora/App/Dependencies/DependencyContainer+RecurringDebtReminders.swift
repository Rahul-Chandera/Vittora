import Foundation

extension DependencyContainer {
    /// Refreshes recurring pre-notifications and self debt due reminders.
    @MainActor
    func refreshRecurringAndDebtReminders() async {
        try? await scheduleRecurringPreNotificationsUseCase.execute()
        try? await scheduleSelfDebtDueRemindersUseCase.execute()
    }
}
