import Foundation
import VittoraCore

enum CurrencyFormatter {
    static func format(_ amount: Decimal, currencyCode: String = CurrencyDefaults.code) -> String {
        amount.formatted(currencyCode: currencyCode)
    }

    static func formatCompact(_ amount: Decimal, currencyCode: String = CurrencyDefaults.code) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    static func formatAbbreviated(_ amount: Decimal, currencyCode: String = CurrencyDefaults.code) -> String {
        let abbreviated = amount.abbreviated()
        if abbreviated.contains("K") || abbreviated.contains("M") {
            return abbreviated
        }
        return format(amount, currencyCode: currencyCode)
    }

    static func formatSigned(
        _ amount: Decimal,
        type: TransactionType,
        currencyCode: String = CurrencyDefaults.code
    ) -> String {
        let formatted = format(amount, currencyCode: currencyCode)
        switch type {
        case .expense:
            return "-\(formatted)"
        case .income:
            return "+\(formatted)"
        case .transfer, .adjustment:
            return formatted
        }
    }
}
