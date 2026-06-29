import Foundation
import SwiftData
import VittoraCore

@Model
final class SDTransaction {
    #Index<SDTransaction>([\.date], [\.accountID], [\.categoryID], [\.typeRawValue])

    var id: UUID = UUID()
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
    /// Links the two legs of a transfer (Schema V2, DATAINTEGRITY-1). Optional
    /// for CloudKit additive compatibility; nil on all pre-V2 and non-transfer rows.
    var transferPairID: UUID?
    /// Raw value of the transfer leg's `TransferDirection` (Schema V3, A3). Optional
    /// for CloudKit additive compatibility; nil on non-transfer and legacy rows.
    var transferDirectionRawValue: String?
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
        transferPairID: UUID? = nil,
        transferDirection: TransferDirection? = nil,
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
        self.transferPairID = transferPairID
        self.transferDirectionRawValue = transferDirection?.rawValue
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

    var transferDirection: TransferDirection? {
        get { transferDirectionRawValue.flatMap(TransferDirection.init(rawValue:)) }
        set { transferDirectionRawValue = newValue?.rawValue }
    }
}
