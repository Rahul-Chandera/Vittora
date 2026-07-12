import Foundation
import VittoraCore

extension Decimal {
    /// Parses a user-entered monetary amount using the locale's decimal and grouping
    /// separators (DATAINTEGRITY-5 / CODEQUALITY-2, A9).
    ///
    /// Returns `nil` for whitespace-only, unparseable, or non-finite input — never
    /// silently coerces to zero. Callers must surface a validation error when this
    /// returns `nil` for non-empty user input.
    ///
    /// Examples (locale-dependent):
    /// - `en_US`: `"1,000"` → 1000, `"1,000.50"` → 1000.50
    /// - `de_DE`: `"1.000,50"` → 1000.50
    /// - `fr_FR`: `"1,5"` → 1.5
    init?(localizedAmount string: String, locale: Locale = .current) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        guard let number = formatter.number(from: trimmed) else { return nil }
        let value = number.decimalValue
        guard value.isFiniteDecimal else { return nil }
        self = value
    }
}
