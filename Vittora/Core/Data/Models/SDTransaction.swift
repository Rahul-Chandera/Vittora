import Foundation
import SwiftData

@Model
final class SDTransaction {
    #Index<SDTransaction>([\.date], [\.accountID], [\.categoryID], [\.typeRawValue])

    @Attribute(.unique) var id: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date.now
    var note: String?
    var typeRawValue: String = TransactionType.expense.rawValue
    var paymentMethodRawValue: String = PaymentMethod.cash.rawValue
    var currencyCode: String = CurrencyDefaults.code
    var tags: [String] = []
    var categoryID: UUID?
    var accountID: UUID?
    var payeeID: UUID?
    var destinationAccountID: UUID?
    var recurringRuleID: UUID?
    var externalID: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = .now,
        note: String? = nil,
        type: TransactionType = .expense,
        paymentMethod: PaymentMethod = .cash,
        currencyCode: String = CurrencyDefaults.code,
        tags: [String] = [],
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        payeeID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        recurringRuleID: UUID? = nil,
        externalID: String = UUID().uuidString,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.typeRawValue = type.rawValue
        self.paymentMethodRawValue = paymentMethod.rawValue
        self.currencyCode = currencyCode
        self.tags = tags
        self.categoryID = categoryID
        self.accountID = accountID
        self.payeeID = payeeID
        self.destinationAccountID = destinationAccountID
        self.recurringRuleID = recurringRuleID
        self.externalID = externalID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRawValue) ?? .cash }
        set { paymentMethodRawValue = newValue.rawValue }
    }
}
