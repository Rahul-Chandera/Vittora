import Foundation

public enum DebtDirection: String, Sendable, Hashable, CaseIterable, Codable {
    /// User lent money — the other party owes the user
    case lent
    /// User borrowed money — the user owes the other party
    case borrowed

    public var displayName: String {
        switch self {
        case .lent:     return String(localized: "Lent")
        case .borrowed: return String(localized: "Borrowed")
        }
    }
}

public struct DebtEntry: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var payeeID: UUID
    public nonisolated var amount: Decimal
    public nonisolated var settledAmount: Decimal
    public nonisolated var direction: DebtDirection
    public nonisolated var dueDate: Date?
    public nonisolated var note: String?
    public nonisolated var isSettled: Bool
    /// Cash legs created by each partial/full settlement (A11, DATAINTEGRITY-7).
    /// Append-only — never overwrite on a subsequent settlement.
    public nonisolated var linkedTransactionIDs: [UUID]
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public var remainingAmount: Decimal { amount - settledAmount }

    public var isOverdue: Bool {
        guard let due = dueDate, !isSettled else { return false }
        return due < Date.now
    }

    public nonisolated init(
        id: UUID = UUID(),
        payeeID: UUID,
        amount: Decimal,
        settledAmount: Decimal = 0,
        direction: DebtDirection,
        dueDate: Date? = nil,
        note: String? = nil,
        isSettled: Bool = false,
        linkedTransactionIDs: [UUID] = [],
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
        self.linkedTransactionIDs = linkedTransactionIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct DebtLedgerEntry: Sendable, Identifiable {
    public var id: UUID { payee.id }
    public let payee: PayeeEntity
    public let entries: [DebtEntry]
    public let totalLent: Decimal       // outstanding money they owe you
    public let totalBorrowed: Decimal   // outstanding money you owe them
    public var netBalance: Decimal { totalLent - totalBorrowed }

    public init(
        payee: PayeeEntity,
        entries: [DebtEntry],
        totalLent: Decimal,
        totalBorrowed: Decimal
    ) {
        self.payee = payee
        self.entries = entries
        self.totalLent = totalLent
        self.totalBorrowed = totalBorrowed
    }
}
