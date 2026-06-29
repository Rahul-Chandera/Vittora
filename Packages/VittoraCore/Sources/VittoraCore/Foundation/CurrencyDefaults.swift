import Foundation

public enum CurrencyDefaults {
    public nonisolated static let fallbackCode = "USD"

    public nonisolated static var code: String {
        Locale.current.currency?.identifier ?? fallbackCode
    }

    public nonisolated static var symbol: String {
        symbol(for: code)
    }

    public nonisolated static func symbol(for code: String) -> String {
        NSLocale(localeIdentifier: "en_US_POSIX")
            .displayName(forKey: .currencySymbol, value: code) ?? code
    }
}
