import SwiftUI

private enum DependencyContainerEnvironment {
    static let previewContainer: DependencyContainer = DependencyContainer.preview()
}

extension EnvironmentValues {
    @Entry var dependencies: DependencyContainer = DependencyContainerEnvironment.previewContainer
    @Entry var currencyCode: String = CurrencyDefaults.code
    @Entry var currencySymbol: String = CurrencyDefaults.symbol
}

extension String {
    /// Return the currency symbol for an ISO 4217 currency code (e.g. "USD" → "$").
    static func currencySymbol(for code: String) -> String {
        CurrencyDefaults.symbol(for: code)
    }
}
