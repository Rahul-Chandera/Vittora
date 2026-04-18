import SwiftUI

extension EnvironmentValues {
    @Entry var dependencies: DependencyContainer = DependencyContainer()
    @Entry var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    @Entry var currencySymbol: String = Locale.current.currencySymbol ?? "$"
}

extension String {
    /// Return the currency symbol for an ISO 4217 currency code (e.g. "USD" → "$").
    static func currencySymbol(for code: String) -> String {
        NSLocale(localeIdentifier: "en_US_POSIX")
            .displayName(forKey: .currencySymbol, value: code) ?? code
    }
}
