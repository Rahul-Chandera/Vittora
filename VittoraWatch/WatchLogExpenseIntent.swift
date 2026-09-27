import AppIntents
import VittoraCore

/// "Hey Siri, log an expense in Vittora" → "What did you spend?" → "500 for
/// groceries" (M2.6.2).
///
/// Two turns, not one: an App Shortcut phrase can only carry entity or enum
/// parameters, never a free-form number, so "Add 500 for groceries in Vittora"
/// cannot be a single registered phrase. Siri asks once and the answer is
/// parsed exactly like in-app dictation.
struct LogExpenseByVoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense"
    static let description = IntentDescription("Log an expense by saying what you spent, like “500 for groceries”.")

    @Parameter(title: "Expense", requestValueDialog: IntentDialog("What did you spend?"))
    var spoken: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = WatchVoiceExpense.parse(spoken)
        guard let amount = parsed.amount else {
            return .result(dialog: IntentDialog("I didn't catch an amount. Try “500 for groceries”."))
        }

        let store = WatchStores.snapshot
        await store.activateAndWait()
        let currencyCode = store.snapshot?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let formatted = amount.formatted(.currency(code: currencyCode))
        let categoryName = store.localCategory(for: parsed)?.name
            ?? (parsed.categoryPhrase.isEmpty ? nil : parsed.categoryPhrase)

        guard store.enqueueVoiceExpense(amount: amount, parsed: parsed) else {
            return .result(dialog: IntentDialog("Vittora couldn't reach your iPhone. Try again from the app."))
        }
        if let categoryName {
            return .result(dialog: IntentDialog("Logged \(formatted) for \(categoryName)."))
        }
        return .result(dialog: IntentDialog("Logged \(formatted)."))
    }
}

struct VittoraWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseByVoiceIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "mic"
        )
    }
}
