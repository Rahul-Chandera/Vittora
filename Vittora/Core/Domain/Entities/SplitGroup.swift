import Foundation

// MARK: - Split Method

enum SplitMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case equal
    case percentage
    case exact
    case shares

    var displayName: String {
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
struct SplitShare: Identifiable, Hashable, Equatable, Sendable, Codable {
    var id: UUID { memberID }
    let memberID: UUID
    var amount: Decimal

    init(memberID: UUID, amount: Decimal = 0) {
        self.memberID = memberID
        self.amount = amount
    }
}

// MARK: - Group Expense

struct GroupExpense: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var groupID: UUID
    /// The member (payee) who paid the full amount upfront
    var paidByMemberID: UUID
    var amount: Decimal
    var title: String
    var date: Date
    var splitMethod: SplitMethod
    /// Per-member share amounts (all shares should sum to `amount`)
    var shares: [SplitShare]
    var categoryID: UUID?
    var note: String?
    var isSettled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
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

struct SplitGroup: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var name: String
    /// Ordered list of payee UUIDs who are members of this group
    var memberIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
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
struct MemberBalance: Sendable, Hashable, Equatable {
    let fromMemberID: UUID
    let toMemberID: UUID
    var amount: Decimal
}

/// Aggregated view of a group's financial state
struct SplitGroupSummary: Sendable, Identifiable {
    var id: UUID { group.id }
    let group: SplitGroup
    let memberNames: [UUID: String]
    let expenses: [GroupExpense]
    var totalExpenses: Decimal { expenses.reduce(0) { $0 + $1.amount } }
    var outstandingCount: Int { expenses.filter { !$0.isSettled }.count }
    var simplifiedBalances: [MemberBalance]
}
