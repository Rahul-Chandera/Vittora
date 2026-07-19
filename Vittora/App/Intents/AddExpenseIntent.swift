import AppIntents
import VittoraCore

/// Opens Vittora into Quick Entry for a new expense (reuses W4 `vittora://add` routing).
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Expense" }
    static var description: IntentDescription {
        IntentDescription("Open Quick Entry to add an expense")
    }

    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAddDeepLink.requestFromIntent(.expense)
        return .result()
    }
}
