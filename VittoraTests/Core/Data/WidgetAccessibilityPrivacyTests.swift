import Foundation
import Testing
import VittoraCore

@Suite("Widget accessibility privacy")
struct WidgetAccessibilityPrivacyTests {
    @Test("redacted privacy labels expose no digits or currency symbols")
    func redactedLabelsExposeNoAmounts() {
        let redactedLabels = [
            WidgetAccessibilityLabels.lockScreenBudget,
            WidgetAccessibilityLabels.lockScreenSpending,
            WidgetAccessibilityLabels.watchComplication,
        ]

        for label in redactedLabels {
            let hasDigits = label.contains { $0.isNumber }
            let hasCurrency = containsCurrencySymbol(label)
            #expect(!hasDigits)
            #expect(!hasCurrency)
        }
    }

    @Test("unredacted labels include the formatted amount")
    func unredactedLabelsIncludeFormattedAmount() throws {
        let amount = try #require(Decimal(string: "9876.54"))
        let currencyCode = "USD"
        let formattedAmount = amount.formatted(.currency(code: currencyCode))

        let todayLabel = WidgetAccessibilityLabels.todaySpending(
            amount: amount,
            changePercentVsYesterday: nil,
            currencyCode: currencyCode
        )
        let budgetLabel = WidgetAccessibilityLabels.budgetRemaining(
            amount: amount,
            progress: 0.42,
            currencyCode: currencyCode
        )
        let combinedLabel = WidgetAccessibilityLabels.todaySpendingAndBudgetRemaining(
            todayAmount: amount,
            remainingAmount: amount,
            progress: 0.42,
            currencyCode: currencyCode
        )

        #expect(todayLabel.contains(formattedAmount))
        #expect(budgetLabel.contains(formattedAmount))
        #expect(combinedLabel.contains(formattedAmount))
    }

    @Test("privacy-sensitive views switch labels on redactionReasons.privacy")
    func privacySensitiveViewsWireConditionalLabels() throws {
        let lockScreenSource = try source(at: "VittoraWidgets/LockScreenAccessoryWidget.swift")
        #expect(lockScreenSource.contains(".privacySensitive()"))
        #expect(lockScreenSource.contains("@Environment(\\.redactionReasons)"))
        #expect(lockScreenSource.contains("redactionReasons.contains(.privacy)"))
        #expect(lockScreenSource.contains("WidgetAccessibilityLabels.lockScreenBudget"))
        #expect(lockScreenSource.contains("WidgetAccessibilityLabels.lockScreenSpending"))
        #expect(lockScreenSource.contains("WidgetAccessibilityLabels.todaySpending("))
        #expect(lockScreenSource.contains("WidgetAccessibilityLabels.budgetRemaining("))
        #expect(lockScreenSource.contains("WidgetAccessibilityLabels.todaySpendingAndBudgetRemaining("))

        let complicationSource = try source(at: "VittoraWatchWidgets/WatchComplications.swift")
        #expect(complicationSource.contains(".privacySensitive()"))
        #expect(complicationSource.contains("@Environment(\\.redactionReasons)"))
        #expect(complicationSource.contains("redactionReasons.contains(.privacy)"))
        #expect(complicationSource.contains("WidgetAccessibilityLabels.watchComplication"))
        #expect(complicationSource.contains("WidgetAccessibilityLabels.todaySpendingAndBudgetRemaining("))
    }

    private func containsCurrencySymbol(_ text: String) -> Bool {
        let codes = ["USD", "EUR", "GBP", "JPY", "INR"]
        for code in codes {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            if let symbol = formatter.currencySymbol, !symbol.isEmpty, text.contains(symbol) {
                return true
            }
        }
        return false
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
