import Foundation
import Observation

@Observable
@MainActor
final class ReceiptReviewViewModel {
    private static let receiptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var merchantName: String
    var amountString: String
    var dateString: String
    var rawText: String

    var amount: Decimal? { Decimal(string: amountString) }

    var date: Date? {
        Self.receiptDateFormatter.date(from: dateString)
    }

    init(receiptData: ReceiptData) {
        self.merchantName = receiptData.merchantName ?? ""
        self.amountString = receiptData.totalAmount.map { "\($0)" } ?? ""
        self.rawText = receiptData.rawText

        self.dateString = receiptData.date.map { Self.receiptDateFormatter.string(from: $0) } ?? ""
    }

    var isValid: Bool {
        !merchantName.isEmpty && amount != nil
    }

    func buildPrefilledTransaction() -> (amount: Decimal, note: String, date: Date) {
        return (
            amount: amount ?? 0,
            note: merchantName,
            date: date ?? .now
        )
    }
}
