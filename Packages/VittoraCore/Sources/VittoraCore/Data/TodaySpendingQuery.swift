import Foundation

/// Builds the GetTodaySpendingIntent result using `WidgetDataProvider` + App Lock gate.
public enum TodaySpendingQuery: Sendable {
    public nonisolated static var loadFailedMessage: String {
        String(localized: "Unable to load today's spending.")
    }

    /// Reads App Lock mirror + today's expenses from the shared store.
    public static func run(
        isAppLockEnabled: Bool = AppLockSessionMirror.isAppLockEnabled,
        isAppLocked: Bool = AppLockSessionMirror.isAppLocked,
        provider: WidgetDataProvider? = nil
    ) async -> String {
        if AppLockDisclosureGate.blocksDisclosure(
            isAppLockEnabled: isAppLockEnabled,
            isAppLocked: isAppLocked
        ) {
            return AppLockDisclosureGate.unlockRequiredMessage
        }

        do {
            let dataProvider = try provider ?? WidgetDataProvider.makeSharedReadOnly()
            let spending = try await dataProvider.todaySpending()
            return AppLockDisclosureGate.todaySpendingMessage(
                isAppLockEnabled: false,
                isAppLocked: false,
                amount: spending.amount,
                currencyCode: spending.currencyCode
            )
        } catch {
            return loadFailedMessage
        }
    }
}
