import AppIntents

/// Donates the W5 App Shortcuts phrases to Siri / Shortcuts.
struct VittoraAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodaySpendingIntent(),
            phrases: [
                "How much did I spend today in \(.applicationName)",
            ],
            shortTitle: "Today's Spending",
            systemImageName: "dollarsign.circle"
        )
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Log spending in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: LogExpenseFromMessageIntent(),
            phrases: [
                "Log a bank message in \(.applicationName)",
            ],
            shortTitle: "Log from Message",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle"
        )
    }
}
