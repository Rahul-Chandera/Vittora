import Foundation

/// Fail-closed gate for exposing financial amounts outside the unlocked app UI
/// (App Intents / Siri / widgets). Amounts must not leak while App Lock is on
/// and the session is locked.
public enum AppLockDisclosureGate: Sendable {
    /// `true` when financial amounts must be withheld.
    public nonisolated static func blocksDisclosure(
        isAppLockEnabled: Bool,
        isAppLocked: Bool
    ) -> Bool {
        isAppLockEnabled && isAppLocked
    }

    public nonisolated static var unlockRequiredMessage: String {
        String(localized: "Unlock Vittora to see your spending")
    }

    /// Spoken/displayed spending line, or the unlock refusal when gated.
    public nonisolated static func todaySpendingMessage(
        isAppLockEnabled: Bool,
        isAppLocked: Bool,
        amount: Decimal,
        currencyCode: String
    ) -> String {
        if blocksDisclosure(isAppLockEnabled: isAppLockEnabled, isAppLocked: isAppLocked) {
            return unlockRequiredMessage
        }
        let formatted = amount.formatted(.currency(code: currencyCode))
        return String(localized: "You've spent \(formatted) today.")
    }
}
