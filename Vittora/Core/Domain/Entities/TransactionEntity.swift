import Foundation

enum TransactionType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income, transfer, adjustment
}

enum PaymentMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, creditCard, debitCard, bankTransfer, upi, wallet, other
}

struct TransactionEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var amount: Decimal
    var date: Date
    var note: String?
    var type: TransactionType
    var paymentMethod: PaymentMethod
    var currencyCode: String
    var tags: [String]
    var categoryID: UUID?
    var accountID: UUID?
    var payeeID: UUID?
    var destinationAccountID: UUID?
    var recurringRuleID: UUID?
    var documentIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = .now,
        note: String? = nil,
        type: TransactionType = .expense,
        paymentMethod: PaymentMethod = .cash,
        currencyCode: String = "USD",
        tags: [String] = [],
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        payeeID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        recurringRuleID: UUID? = nil,
        documentIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.type = type
        self.paymentMethod = paymentMethod
        self.currencyCode = currencyCode
        self.tags = tags
        self.categoryID = categoryID
        self.accountID = accountID
        self.payeeID = payeeID
        self.destinationAccountID = destinationAccountID
        self.recurringRuleID = recurringRuleID
        self.documentIDs = documentIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
