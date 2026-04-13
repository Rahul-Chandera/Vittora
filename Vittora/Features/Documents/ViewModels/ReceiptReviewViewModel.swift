import Foundation
import Observation

@Observable
@MainActor
final class ReceiptReviewViewModel {
    var merchantName: String
    var amountString: String
    var dateString: String
    var rawText: String

    var amount: Decimal? { Decimal(string: amountString) }

    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: dateString)
    }

    init(receiptData: ReceiptData) {
        self.merchantName = receiptData.merchantName ?? ""
        self.amountString = receiptData.totalAmount.map { "\($0)" } ?? ""
        self.rawText = receiptData.rawText

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        self.dateString = receiptData.date.map { formatter.string(from: $0) } ?? ""
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
