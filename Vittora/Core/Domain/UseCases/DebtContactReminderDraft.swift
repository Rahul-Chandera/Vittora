import Foundation

/// User-initiated reminder copy for debts others owe you (C5 / M1.4.3).
/// Never sent automatically — only surfaced through ShareLink / share UI.
enum DebtContactReminderDraft {
    static func message(
        payeeName: String,
        remainingAmount: Decimal,
        dueDate: Date?,
        currencyCode: String
    ) -> String {
        let amount = remainingAmount.formatted(.currency(code: currencyCode))
        if let dueDate {
            let due = dueDate.formatted(date: .abbreviated, time: .omitted)
            return String(
                localized: "Hi \(payeeName), friendly reminder that \(amount) is due by \(due). Thanks!"
            )
        }
        return String(
            localized: "Hi \(payeeName), friendly reminder about the outstanding amount of \(amount). Thanks!"
        )
    }
}
