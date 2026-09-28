import CloudKit
import Foundation

/// Household sharing (M3.4.1–3).
///
/// Household data does NOT live in the SwiftData store. SwiftData can mirror
/// only to the private database — `ModelConfiguration.CloudKitDatabase` has no
/// shared option, even in the iOS 27 SDK — so it cannot take part in a
/// `CKShare`. The household is instead one custom record zone in the owner's
/// private database, shared zone-wide, and synced by `HouseholdStore` with
/// `CKSyncEngine`. It is deliberately small: shared budgets and the expenses
/// members log against them. Personal accounts and transactions never leave
/// the private store.

/// A budget the whole household spends against. Monthly, in one currency.
nonisolated struct HouseholdBudget: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var amount: Decimal
    var currencyCode: String
    var createdAt: Date
}

/// One member's spending against a household budget.
///
/// `memberID` is the member's CloudKit user record name, which is the same on
/// every device and to every member. `memberName` is what the member was
/// called when they logged it — kept on the record because a participant has
/// no other way to learn the names of the people they share with.
nonisolated struct HouseholdExpense: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var budgetID: String
    var amount: Decimal
    var note: String
    var date: Date
    var memberID: String
    var memberName: String
}

// MARK: - CloudKit records

nonisolated enum HouseholdRecordType {
    static let budget = "HouseholdBudget"
    static let expense = "HouseholdExpense"
}

nonisolated extension HouseholdBudget {
    /// Money travels as a string. A CloudKit double would round-trip `Decimal`
    /// through binary floating point and lose cents.
    init?(record: CKRecord) {
        guard record.recordType == HouseholdRecordType.budget,
              let name = record["name"] as? String,
              let amountText = record["amount"] as? String,
              let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
              let currencyCode = record["currencyCode"] as? String
        else { return nil }
        self.init(
            id: record.recordID.recordName,
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? .now
        )
    }

    func makeRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: HouseholdRecordType.budget,
            recordID: CKRecord.ID(recordName: id, zoneID: zoneID)
        )
        record["name"] = name
        record["amount"] = HouseholdMoney.string(amount)
        record["currencyCode"] = currencyCode
        record["createdAt"] = createdAt
        return record
    }
}

nonisolated extension HouseholdExpense {
    init?(record: CKRecord) {
        guard record.recordType == HouseholdRecordType.expense,
              let budgetID = record["budgetID"] as? String,
              let amountText = record["amount"] as? String,
              let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
              let date = record["date"] as? Date,
              let memberID = record["memberID"] as? String
        else { return nil }
        self.init(
            id: record.recordID.recordName,
            budgetID: budgetID,
            amount: amount,
            note: record["note"] as? String ?? "",
            date: date,
            memberID: memberID,
            memberName: record["memberName"] as? String ?? ""
        )
    }

    func makeRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: HouseholdRecordType.expense,
            recordID: CKRecord.ID(recordName: id, zoneID: zoneID)
        )
        record["budgetID"] = budgetID
        record["amount"] = HouseholdMoney.string(amount)
        record["note"] = note
        record["date"] = date
        record["memberID"] = memberID
        record["memberName"] = memberName
        return record
    }
}

nonisolated enum HouseholdMoney {
    /// Locale-independent, so "1234.5" written on a device set to German is
    /// read back as the same number on one set to English.
    static func string(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }
}

// MARK: - Ledger

/// The household's shared state and the arithmetic over it. Pure, so the
/// sync engine's effects can be tested without CloudKit.
nonisolated struct HouseholdLedger: Codable, Equatable, Sendable {
    var budgets: [HouseholdBudget] = []
    var expenses: [HouseholdExpense] = []

    /// Applies a batch of fetched changes. A record arriving again replaces
    /// the copy held — the server is the source of truth for anything it sends.
    mutating func apply(modified records: [CKRecord], deletedRecordNames: [String]) {
        for record in records {
            if let budget = HouseholdBudget(record: record) {
                budgets.removeAll { $0.id == budget.id }
                budgets.append(budget)
            } else if let expense = HouseholdExpense(record: record) {
                expenses.removeAll { $0.id == expense.id }
                expenses.append(expense)
            }
        }
        let deleted = Set(deletedRecordNames)
        budgets.removeAll { deleted.contains($0.id) }
        expenses.removeAll { deleted.contains($0.id) }
        budgets.sort { $0.createdAt < $1.createdAt }
    }

    /// Expenses logged against `budget` in the calendar month containing `now`.
    /// Household budgets are monthly and reset on the 1st, like personal ones.
    func expenses(for budget: HouseholdBudget, in now: Date = .now, calendar: Calendar = .current) -> [HouseholdExpense] {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
        return expenses
            .filter { $0.budgetID == budget.id && month.contains($0.date) }
            .sorted { $0.date > $1.date }
    }

    func spent(for budget: HouseholdBudget, in now: Date = .now, calendar: Calendar = .current) -> Decimal {
        expenses(for: budget, in: now, calendar: calendar).reduce(0) { $0 + $1.amount }
    }

    /// M3.4.2 "individual tracking": each member's share of this month's
    /// spending, largest first. Grouped by member ID, not name — two members
    /// can share a first name, and a member can rename themselves.
    func memberTotals(for budget: HouseholdBudget, in now: Date = .now, calendar: Calendar = .current) -> [MemberTotal] {
        let grouped = Dictionary(grouping: expenses(for: budget, in: now, calendar: calendar), by: \.memberID)
        return grouped.map { memberID, items in
            // The most recent name the member logged under. Blank names —
            // logged before CloudKit knew who they were — never win over a
            // real one.
            let name = items.filter { !$0.memberName.isEmpty }.max { $0.date < $1.date }?.memberName ?? ""
            return MemberTotal(memberID: memberID, name: name, total: items.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.total != $1.total ? $0.total > $1.total : $0.name < $1.name }
    }

    /// Removing a budget takes its expenses with it; left behind they would be
    /// unreachable and still synced to every member.
    func expenseIDs(belongingTo budgetID: String) -> [String] {
        expenses.filter { $0.budgetID == budgetID }.map(\.id)
    }

    struct MemberTotal: Equatable, Sendable, Identifiable {
        let memberID: String
        let name: String
        let total: Decimal
        var id: String { memberID }
    }
}

// MARK: - Roles and permissions (M3.4.3)

nonisolated enum HouseholdRole: String, Codable, Sendable {
    /// Not in a household.
    case none
    /// Created the household; it lives in this user's private database.
    case owner
    /// Accepted someone else's invitation; reads it through the shared database.
    case participant
}

nonisolated enum HouseholdAccess {
    /// Whether this member may add or remove anything. The owner always can.
    /// A participant can only when the owner invited them with "Can make
    /// changes" — CloudKit enforces the same rule server-side, so this only
    /// keeps the UI from offering what the server will refuse.
    static func canEdit(role: HouseholdRole, permission: CKShare.ParticipantPermission?) -> Bool {
        switch role {
        case .owner: true
        case .participant: permission == .readWrite
        case .none: false
        }
    }
}
