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
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle"
        )
    }
}
