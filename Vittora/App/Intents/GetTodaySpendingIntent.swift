import AppIntents
import VittoraCore

/// Siri/Shortcuts query for today's expense total (runs without opening the app).
struct GetTodaySpendingIntent: AppIntent {
    static var title: LocalizedStringResource { "Today's Spending" }
    static var description: IntentDescription {
        IntentDescription("Reports how much you've spent today")
    }

    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = await TodaySpendingQuery.run()
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
