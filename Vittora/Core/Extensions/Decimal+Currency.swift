import Foundation

extension Decimal {
    /// Format decimal as currency with specified currency code.
    ///
    /// - Parameter currencyCode: ISO 4217 currency code (e.g., "USD", "EUR", "GBP")
    /// - Returns: Formatted currency string
    func formatted(currencyCode: String = CurrencyDefaults.code) -> String {
        formatted(.currency(code: currencyCode))
    }

    /// Format decimal with custom number formatter (for callers that require legacy NumberFormatter).
    func formatted(with formatter: NumberFormatter) -> String {
        formatter.string(from: NSDecimalNumber(decimal: self)) ?? "~"
    }

    /// Absolute value of the decimal.
    var absoluteValue: Decimal {
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

    /// True when the value is representable as a finite double (used for sync integrity checks).
    var isFiniteDecimal: Bool {
        Double(truncating: NSDecimalNumber(decimal: self)).isFinite
    }

    /// Format as percentage with specified decimal places.
    ///
    /// - Parameter decimalPlaces: Number of decimal places (default: 2)
    /// - Returns: Percentage string (e.g., "25.50%")
    func asPercentage(decimalPlaces: Int = 2) -> String {
        formatted(.percent.precision(.fractionLength(decimalPlaces)))
    }

    /// Round to specified number of decimal places.
    ///
    /// - Parameter decimalPlaces: Number of decimal places
    /// - Returns: Rounded decimal
    func rounded(to decimalPlaces: Int) -> Decimal {
        let behaviorNotation = NSDecimalNumberHandler(
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
        let absValue = self.absoluteValue

        if absValue >= 1_000_000 {
            let millions = absValue / 1_000_000
            return (self < 0 ? "-" : "") + String(format: "%.1fM", NSDecimalNumber(decimal: millions).doubleValue)
        } else if absValue >= 1_000 {
            let thousands = absValue / 1_000
            return (self < 0 ? "-" : "") + String(format: "%.1fK", NSDecimalNumber(decimal: thousands).doubleValue)
        } else {
            return formatted()
        }
    }
}
