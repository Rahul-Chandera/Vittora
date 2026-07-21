import Foundation
import Testing
import VittoraCore

@Suite("Widget accessibility privacy")
struct WidgetAccessibilityPrivacyTests {
    @Test("privacy-sensitive widget labels never expose redacted amounts")
    func privacySensitiveLabelsDoNotExposeAmounts() throws {
        let canary = try #require(Decimal(string: "9876.54"))
        let formattedCanary = canary.formatted(.currency(code: "USD"))
        let labels = [
            WidgetAccessibilityLabels.lockScreenBudget,
            WidgetAccessibilityLabels.lockScreenSpending,
            WidgetAccessibilityLabels.watchComplication,
        ]

        #expect(labels.allSatisfy { !$0.contains(formattedCanary) })

        let lockScreenSource = try source(at: "VittoraWidgets/LockScreenAccessoryWidget.swift")
        #expect(lockScreenSource.contains(".privacySensitive()"))
        #expect(lockScreenSource.contains(
            ".accessibilityLabel(WidgetAccessibilityLabels.lockScreenBudget)"
        ))
        #expect(lockScreenSource.contains(
            ".accessibilityLabel(WidgetAccessibilityLabels.lockScreenSpending)"
        ))

        let complicationSource = try source(at: "VittoraWatchWidgets/WatchComplications.swift")
        #expect(complicationSource.contains(".privacySensitive()"))
        #expect(complicationSource.contains(
            ".accessibilityLabel(WidgetAccessibilityLabels.watchComplication)"
        ))
    }

    private func source(at relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
