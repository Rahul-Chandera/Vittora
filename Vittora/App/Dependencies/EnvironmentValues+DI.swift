import SwiftUI

extension EnvironmentValues {
    @Entry var dependencies: DependencyContainer = DependencyContainer()
    @Entry var currencyCode: String = CurrencyDefaults.code
    @Entry var currencySymbol: String = CurrencyDefaults.symbol
}

extension String {
    /// Return the currency symbol for an ISO 4217 currency code (e.g. "USD" → "$").
    static func currencySymbol(for code: String) -> String {
        CurrencyDefaults.symbol(for: code)
    }
}
