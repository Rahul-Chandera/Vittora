import Foundation
import Testing

@Suite("Watch crown accessibility wiring")
struct WatchCrownAccessibilityWiringTests {
    @Test("crown amount changes post their formatted value to VoiceOver")
    func crownChangesAnnounceAmount() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "VittoraWatch/WatchQuickExpenseView.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains(".onChange(of: amount.cents)"))
        #expect(source.contains("AccessibilityNotification.Announcement("))
        #expect(source.contains("amount.decimal.formatted(.currency(code: currencyCode))"))
    }
}
