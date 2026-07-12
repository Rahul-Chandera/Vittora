import Foundation
import SwiftData

extension VittoraSchemaV1 {
    /// Frozen transaction shape for Schema V1 (no transfer columns).
    @Model
    public final class SDTransaction {
        #Index<SDTransaction>([\.date], [\.accountID], [\.categoryID], [\.typeRawValue])

        public var id: UUID = UUID()
        public var amount: Decimal = 0
        public var date: Date = Date.now
        public var note: String?
        public var typeRawValue: String = TransactionType.expense.rawValue
        public var paymentMethodRawValue: String = PaymentMethod.cash.rawValue
        public var currencyCode: String = CurrencyDefaults.code
        public var tags: [String] = []
        public var categoryID: UUID?
        public var accountID: UUID?
        public var payeeID: UUID?
        public var destinationAccountID: UUID?
        public var recurringRuleID: UUID?
        public var externalID: String = ""
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public init() {}

        public init(
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

        public var type: TransactionType {
            get { TransactionType(rawValue: typeRawValue) ?? .expense }
            set { typeRawValue = newValue.rawValue }
        }

        public var paymentMethod: PaymentMethod {
            get { PaymentMethod(rawValue: paymentMethodRawValue) ?? .cash }
            set { paymentMethodRawValue = newValue.rawValue }
        }
    }
}
