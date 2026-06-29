import Foundation
import VittoraCore

extension DependencyContainer {
    /// Refreshes pre-due reminders for credit cards with a payment due day configured.
    @MainActor
    func refreshCreditCardDueReminders() async {
        try? await scheduleCreditCardDueRemindersUseCase.execute()
    }
}
