import Foundation

enum CurrencyDefaults {
    nonisolated static let fallbackCode = "USD"

    nonisolated static var code: String {
        Locale.current.currency?.identifier ?? fallbackCode
    }

    nonisolated static var symbol: String {
        symbol(for: code)
    }

    nonisolated static func symbol(for code: String) -> String {
        NSLocale(localeIdentifier: "en_US_POSIX")
            .displayName(forKey: .currencySymbol, value: code) ?? code
    }
}
