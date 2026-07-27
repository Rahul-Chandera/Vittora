import Foundation
import VittoraCore

/// Single source of truth for text drawn on the shareable Year in Review image.
enum YearInReviewShareCopy {
    static func lines(
        summary: YearInReviewSummary,
        includeAmounts: Bool,
        currencyCode: String
    ) -> [String] {
        var lines: [String] = [
            String(localized: "My \(String(summary.year)) with Vittora"),
        ]

        if includeAmounts {
            lines.append(CurrencyFormatter.format(summary.totalSpent, currencyCode: currencyCode))
            lines.append(String(localized: "spent this year"))
        } else {
            lines.append(String(localized: "A year of tracking"))
        }

        if !summary.topCategories.isEmpty {
            lines.append(String(localized: "Top categories"))
            for category in summary.topCategories.prefix(4) {
                if includeAmounts {
                    let amount = CurrencyFormatter.format(category.amount, currencyCode: currencyCode)
                    lines.append("\(category.name) · \(category.sharePercent)% · \(amount)")
                } else {
                    lines.append("\(category.name) · \(category.sharePercent)%")
                }
            }
        }

        if let biggest = summary.biggestMonth {
            let month = biggest.monthStart.formatted(.dateTime.month(.wide))
            if includeAmounts {
                let amount = CurrencyFormatter.format(biggest.amount, currencyCode: currencyCode)
                lines.append(String(localized: "Biggest month: \(month) · \(amount)"))
            } else {
                lines.append(String(localized: "Biggest month: \(month)"))
            }
        }

        lines.append(
            String(localized: "\(summary.transactionCount) transactions · \(summary.longestStreakDays)-day streak")
        )
        lines.append(String(localized: "Made with Vittora"))
        return lines
    }

    /// True when a line looks like a currency amount (used by privacy tests).
    static func containsCurrencyAmount(_ line: String, currencyCode: String) -> Bool {
        let symbol = CurrencyDefaults.symbol(for: currencyCode)
        if !symbol.isEmpty, line.contains(symbol) { return true }
        // e.g. "USD 1,234.56" / "1,234.56 USD"
        if line.range(of: #"\d[\d,]*\.\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
