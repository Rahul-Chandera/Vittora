import Foundation

enum TransactionType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income, transfer, adjustment
}

enum PaymentMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, creditCard, debitCard, bankTransfer, upi, wallet, other
}

struct TransactionEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var amount: Decimal
    nonisolated var date: Date
    nonisolated var note: String?
    nonisolated var type: TransactionType
    nonisolated var paymentMethod: PaymentMethod
    nonisolated var currencyCode: String
    nonisolated var tags: [String]
    nonisolated var categoryID: UUID?
    nonisolated var accountID: UUID?
    nonisolated var payeeID: UUID?
    nonisolated var destinationAccountID: UUID?
    nonisolated var recurringRuleID: UUID?
    nonisolated var documentIDs: [UUID]
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
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

    // MARK: - Equatable & Hashable (identity-based)

    nonisolated static func == (lhs: TransactionEntity, rhs: TransactionEntity) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
