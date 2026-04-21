import Foundation

enum CurrencyDefaults {
    static let fallbackCode = "USD"

    static var code: String {
        Locale.current.currency?.identifier ?? fallbackCode
    }

    static var symbol: String {
        symbol(for: code)
    }

    static func symbol(for code: String) -> String {
        NSLocale(localeIdentifier: "en_US_POSIX")
            .displayName(forKey: .currencySymbol, value: code) ?? code
    }
}
