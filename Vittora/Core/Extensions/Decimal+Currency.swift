import Foundation

extension Decimal {
    /// Format decimal as currency with specified currency code.
    ///
    /// - Parameter currencyCode: ISO 4217 currency code (e.g., "USD", "EUR", "GBP")
    /// - Returns: Formatted currency string
    func formatted(currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "~"
    }

    /// Format decimal with custom number formatter.
    ///
    /// - Parameter formatter: NumberFormatter to use
    /// - Returns: Formatted string
    func formatted(with formatter: NumberFormatter) -> String {
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "~"
    }

    /// Absolute value of the decimal.
    var abs: Decimal {
        return self < 0 ? -self : self
    }

    /// Check if the decimal is negative.
    var isNegative: Bool {
        return self < 0
    }

    /// Check if the decimal is positive.
    var isPositive: Bool {
        return self > 0
    }

    /// Check if the decimal is zero.
    var isZero: Bool {
        return self == 0
    }

    /// Format as percentage with specified decimal places.
    ///
    /// - Parameter decimalPlaces: Number of decimal places (default: 2)
    /// - Returns: Percentage string (e.g., "25.50%")
    func asPercentage(decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces

        let percentValue = self * 100
        return formatter.string(from: NSDecimalNumber(decimal: percentValue)) ?? "~%"
    }

    /// Round to specified number of decimal places.
    ///
    /// - Parameter decimalPlaces: Number of decimal places
    /// - Returns: Rounded decimal
    func rounded(to decimalPlaces: Int) -> Decimal {
        var result = self
        var behaviorNotation = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: Int16(decimalPlaces),
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )

        let decimalNumber = NSDecimalNumber(decimal: self)
        let rounded = decimalNumber.rounding(accordingToBehavior: behaviorNotation)
        return rounded.decimalValue
    }

    /// Abbreviate large numbers (e.g., 1000 -> "1K", 1000000 -> "1M")
    ///
    /// - Returns: Abbreviated string with suffix
    func abbreviated() -> String {
        let absValue = abs(self)

        if absValue >= 1_000_000 {
            let millions = absValue / 1_000_000
            return (self < 0 ? "-" : "") + String(format: "%.1fM", NSDecimalNumber(decimal: millions).doubleValue)
        } else if absValue >= 1_000 {
            let thousands = absValue / 1_000
            return (self < 0 ? "-" : "") + String(format: "%.1fK", NSDecimalNumber(decimal: thousands).doubleValue)
        } else {
            return formatted(currencyCode: "USD")
        }
    }
}
