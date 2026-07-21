import Foundation

public enum WidgetAccessibilityLabels {
    public static func todaySpending(
        amount: Decimal,
        changePercentVsYesterday: Double?,
        currencyCode: String
    ) -> String {
        let amountText = amount.formatted(.currency(code: currencyCode))
        guard let changePercentVsYesterday else {
            return String(localized: "Today's spending, \(amountText)")
        }

        let percent = Int(abs(changePercentVsYesterday).rounded())
        if percent == 0 {
            return String(localized: "Today's spending, \(amountText), unchanged from yesterday")
        }
        if changePercentVsYesterday > 0 {
            return String(localized: "Today's spending, \(amountText), \(percent)% above yesterday")
        }
        return String(localized: "Today's spending, \(amountText), \(percent)% below yesterday")
    }

    public static func budgetRemaining(
        amount: Decimal,
        progress: Double,
        currencyCode: String
    ) -> String {
        let amountText = amount.formatted(.currency(code: currencyCode))
        let percent = Int(min(max(progress * 100, 0), 999).rounded())
        return String(localized: "Budget remaining, \(amountText), \(percent)% used")
    }

    // Never accept formatted values here: these labels remain safe when the
    // corresponding privacySensitive widget content is redacted while locked.
    public static let lockScreenBudget = String(localized: "Budget progress, values hidden while locked")
    public static let lockScreenSpending = String(
        localized: "Today's spending and budget remaining, values hidden while locked"
    )
    public static let watchComplication = String(
        localized: "Today's spending and budget remaining, values hidden while locked"
    )
}
