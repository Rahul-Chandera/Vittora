import Foundation

enum DebtDirection: String, Sendable, Hashable, CaseIterable, Codable {
    /// User lent money — the other party owes the user
    case lent
    /// User borrowed money — the user owes the other party
    case borrowed

    var displayName: String {
        switch self {
        case .lent:     return String(localized: "Lent")
        case .borrowed: return String(localized: "Borrowed")
        }
    }
}

struct DebtEntry: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var payeeID: UUID
    var amount: Decimal
    var settledAmount: Decimal
    var direction: DebtDirection
    var dueDate: Date?
    var note: String?
    var isSettled: Bool
    var linkedTransactionID: UUID?
    var createdAt: Date
    var updatedAt: Date

    var remainingAmount: Decimal { amount - settledAmount }

    var isOverdue: Bool {
        guard let due = dueDate, !isSettled else { return false }
        return due < Date.now
    }

    nonisolated init(
        id: UUID = UUID(),
        payeeID: UUID,
        amount: Decimal,
        settledAmount: Decimal = 0,
        direction: DebtDirection,
        dueDate: Date? = nil,
        note: String? = nil,
        isSettled: Bool = false,
        linkedTransactionID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.payeeID = payeeID
        self.amount = amount
        self.settledAmount = settledAmount
        self.direction = direction
        self.dueDate = dueDate
        self.note = note
        self.isSettled = isSettled
        self.linkedTransactionID = linkedTransactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DebtLedgerEntry: Sendable, Identifiable {
    var id: UUID { payee.id }
    let payee: PayeeEntity
    let entries: [DebtEntry]
    let totalLent: Decimal       // outstanding money they owe you
    let totalBorrowed: Decimal   // outstanding money you owe them
    var netBalance: Decimal { totalLent - totalBorrowed }
}
