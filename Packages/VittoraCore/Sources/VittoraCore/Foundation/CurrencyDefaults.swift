import Foundation

public enum CurrencyDefaults {
    public nonisolated static let fallbackCode = "USD"

    /// The user's chosen app currency, falling back to the device locale.
    /// Components default their `currencyCode` parameter to this, so it must
    /// reflect the Settings choice — locale alone shows the wrong symbol for
    /// anyone whose device region differs from their selected currency.
    public nonisolated static var code: String {
        UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.currencyCode)
            ?? Locale.current.currency?.identifier
            ?? fallbackCode
    }

    public nonisolated static var symbol: String {
        symbol(for: code)
    }

    public nonisolated static func symbol(for code: String) -> String {
        NSLocale(localeIdentifier: "en_US_POSIX")
            .displayName(forKey: .currencySymbol, value: code) ?? code
    }
}
