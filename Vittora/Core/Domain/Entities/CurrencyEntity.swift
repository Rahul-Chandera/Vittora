import Foundation

struct CurrencyEntity: Identifiable, Hashable, Equatable, Sendable {
    var id: String { code }
    let code: String
    let symbol: String
    let name: String
    let decimalPlaces: Int

    static let allCurrencies: [CurrencyEntity] = [
        CurrencyEntity(code: "USD", symbol: "$", name: "US Dollar", decimalPlaces: 2),
        CurrencyEntity(code: "EUR", symbol: "€", name: "Euro", decimalPlaces: 2),
        CurrencyEntity(code: "GBP", symbol: "£", name: "British Pound", decimalPlaces: 2),
        CurrencyEntity(code: "INR", symbol: "₹", name: "Indian Rupee", decimalPlaces: 2),
        CurrencyEntity(code: "CAD", symbol: "CA$", name: "Canadian Dollar", decimalPlaces: 2),
        CurrencyEntity(code: "AUD", symbol: "A$", name: "Australian Dollar", decimalPlaces: 2),
        CurrencyEntity(code: "JPY", symbol: "¥", name: "Japanese Yen", decimalPlaces: 0),
    ]
}
