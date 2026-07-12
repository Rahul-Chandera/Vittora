import Foundation

// MARK: - Split Method

public enum SplitMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case equal
    case percentage
    case exact
    case shares

    public var displayName: String {
        switch self {
        case .equal:      return String(localized: "Equal")
        case .percentage: return String(localized: "Percentage")
        case .exact:      return String(localized: "Exact Amount")
        case .shares:     return String(localized: "Shares")
        }
    }
}

// MARK: - Split Share

/// Per-member allocation for a single group expense
public struct SplitShare: Identifiable, Sendable, Codable {
    public nonisolated var id: UUID { memberID }
    public nonisolated let memberID: UUID
    public nonisolated var amount: Decimal

    public nonisolated init(memberID: UUID, amount: Decimal = 0) {
        self.memberID = memberID
        self.amount = amount
    }
}

extension SplitShare: Hashable {
    public nonisolated static func == (lhs: SplitShare, rhs: SplitShare) -> Bool {
        lhs.memberID == rhs.memberID && lhs.amount == rhs.amount
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(memberID)
        hasher.combine(amount)
    }
}

// MARK: - Group Expense

public struct GroupExpense: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var groupID: UUID
    /// The member (payee) who paid the full amount upfront
    public nonisolated var paidByMemberID: UUID
    public nonisolated var amount: Decimal
    public nonisolated var title: String
    public nonisolated var date: Date
    public nonisolated var splitMethod: SplitMethod
    /// Per-member share amounts (all shares should sum to `amount`)
    public nonisolated var shares: [SplitShare]
    public nonisolated var categoryID: UUID?
    public nonisolated var note: String?
    public nonisolated var isSettled: Bool
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        groupID: UUID,
        paidByMemberID: UUID,
        amount: Decimal,
        title: String,
        date: Date = .now,
        splitMethod: SplitMethod = .equal,
        shares: [SplitShare] = [],
        categoryID: UUID? = nil,
        note: String? = nil,
        isSettled: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.groupID = groupID
        self.paidByMemberID = paidByMemberID
        self.amount = amount
        self.title = title
        self.date = date
        self.splitMethod = splitMethod
        self.shares = shares
        self.categoryID = categoryID
        self.note = note
        self.isSettled = isSettled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Split Group

public struct SplitGroup: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    /// Ordered list of payee UUIDs who are members of this group
    public nonisolated var memberIDs: [UUID]
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        memberIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Balance Types

/// Net balance between two members — `fromMemberID` owes `toMemberID` the amount
public struct MemberBalance: Sendable, Hashable, Equatable {
    public nonisolated let fromMemberID: UUID
    public nonisolated let toMemberID: UUID
    public nonisolated var amount: Decimal

    public nonisolated init(fromMemberID: UUID, toMemberID: UUID, amount: Decimal) {
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.amount = amount
    }
}

/// Aggregated view of a group's financial state
public struct SplitGroupSummary: Sendable, Identifiable {
    public var id: UUID { group.id }
    public let group: SplitGroup
    public let memberNames: [UUID: String]
    public let expenses: [GroupExpense]
    public var totalExpenses: Decimal { expenses.reduce(0) { $0 + $1.amount } }
    public var outstandingCount: Int { expenses.filter { !$0.isSettled }.count }
    public var simplifiedBalances: [MemberBalance]

    public init(
        group: SplitGroup,
        memberNames: [UUID: String],
        expenses: [GroupExpense],
        simplifiedBalances: [MemberBalance]
    ) {
        self.group = group
        self.memberNames = memberNames
        self.expenses = expenses
        self.simplifiedBalances = simplifiedBalances
    }
}
