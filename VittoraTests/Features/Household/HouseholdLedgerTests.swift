import CloudKit
import Foundation
import Testing
@testable import Vittora

/// Household sharing (M3.4.1–3): the parts that run without CloudKit.
///
/// The sync engine itself needs two signed-in iCloud accounts and cannot run
/// in a unit test. What it does with records — map them, merge them, total
/// them, and decide who may edit — is pure and tested here.
@Suite("Household ledger")
@MainActor
struct HouseholdLedgerTests {

    private let zoneID = CKRecordZone.ID(zoneName: "Household-test", ownerName: CKCurrentUserDefaultName)

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ iso: String) -> Date {
        (try? Date(iso, strategy: .iso8601)) ?? .distantPast
    }

    private func money(_ text: String) -> Decimal { Decimal(string: text) ?? .nan }

    private func budget(_ id: String = "groceries", amount: String = "600.00") -> HouseholdBudget {
        HouseholdBudget(id: id, name: "Groceries", amount: money(amount), currencyCode: "USD", createdAt: date("2026-09-01T00:00:00Z"))
    }

    private func expense(
        _ id: String, amount: String, member: String, name: String,
        on day: String = "2026-09-10T12:00:00Z", budgetID: String = "groceries"
    ) -> HouseholdExpense {
        HouseholdExpense(
            id: id, budgetID: budgetID, amount: money(amount), note: "",
            date: date(day), memberID: member, memberName: name
        )
    }

    // MARK: Record mapping

    /// Money is a string on the wire. A CloudKit double would round cents.
    @Test("a budget survives a CKRecord round trip with its amount exact")
    func budgetRoundTrip() {
        let original = budget(amount: "1234.57")
        let record = original.makeRecord(in: zoneID)
        #expect(record["amount"] as? String == "1234.57")
        #expect(HouseholdBudget(record: record) == original)
    }

    @Test("an expense survives a CKRecord round trip")
    func expenseRoundTrip() {
        let original = expense("e1", amount: "0.10", member: "_member1", name: "Asha")
        #expect(HouseholdExpense(record: original.makeRecord(in: zoneID)) == original)
    }

    /// A record of another type, or one missing its amount, is ignored rather
    /// than turned into a zero-value budget.
    @Test("records that are not valid household records are rejected")
    func rejectsForeignRecords() {
        let other = CKRecord(recordType: "CD_SDTransaction", recordID: CKRecord.ID(recordName: "x", zoneID: zoneID))
        #expect(HouseholdBudget(record: other) == nil)
        #expect(HouseholdExpense(record: other) == nil)

        let broken = budget().makeRecord(in: zoneID)
        broken["amount"] = nil
        #expect(HouseholdBudget(record: broken) == nil)
    }

    // MARK: Merging fetched changes

    @Test("fetched records are added, replaced and deleted")
    func appliesFetchedChanges() {
        var ledger = HouseholdLedger()
        ledger.apply(
            modified: [budget().makeRecord(in: zoneID), expense("e1", amount: "20", member: "a", name: "A").makeRecord(in: zoneID)],
            deletedRecordNames: []
        )
        #expect(ledger.budgets.count == 1)
        #expect(ledger.expenses.count == 1)

        // Same record again, changed on the server: replaced, not duplicated.
        ledger.apply(modified: [budget(amount: "750").makeRecord(in: zoneID)], deletedRecordNames: [])
        #expect(ledger.budgets.count == 1)
        #expect(ledger.budgets.first?.amount == 750)

        ledger.apply(modified: [], deletedRecordNames: ["e1"])
        #expect(ledger.expenses.isEmpty)
    }

    /// The zone-wide share arrives as a record in the same batch; it must not
    /// be mistaken for household data.
    @Test("the share record in a fetch does not become a budget or expense")
    func ignoresShareRecord() {
        var ledger = HouseholdLedger()
        ledger.apply(modified: [CKShare(recordZoneID: zoneID)], deletedRecordNames: [])
        #expect(ledger == HouseholdLedger())
    }

    // MARK: Totals (M3.4.2)

    @Test("spent counts only this budget's expenses in the current month")
    func spentIsMonthly() {
        let ledger = HouseholdLedger(budgets: [budget()], expenses: [
            expense("e1", amount: "40.25", member: "a", name: "A"),
            expense("e2", amount: "10.00", member: "b", name: "B"),
            expense("old", amount: "99.00", member: "a", name: "A", on: "2026-08-31T23:59:00Z"),
            expense("other", amount: "5.00", member: "a", name: "A", budgetID: "fuel"),
        ])
        #expect(ledger.spent(for: budget(), in: date("2026-09-20T00:00:00Z"), calendar: utc) == money("50.25"))
    }

    /// Individual tracking: grouped by member ID, so two people called Sam
    /// are not merged, and a rename doesn't split one person in two.
    @Test("member totals group by member, largest first, under their latest name")
    func memberTotals() {
        let ledger = HouseholdLedger(budgets: [budget()], expenses: [
            expense("e1", amount: "30", member: "_sam1", name: "Sam", on: "2026-09-02T10:00:00Z"),
            expense("e2", amount: "25", member: "_sam2", name: "Sam"),
            expense("e3", amount: "15", member: "_sam1", name: "Sam K", on: "2026-09-12T10:00:00Z"),
        ])
        let totals = ledger.memberTotals(for: budget(), in: date("2026-09-20T00:00:00Z"), calendar: utc)
        #expect(totals.map(\.memberID) == ["_sam1", "_sam2"])
        #expect(totals.first?.total == 45)
        #expect(totals.first?.name == "Sam K")
        #expect(totals.reduce(0) { $0 + $1.total } == ledger.spent(for: budget(), in: date("2026-09-20T00:00:00Z"), calendar: utc))
    }

    /// A member whose name CloudKit could not supply logs with a blank name;
    /// that must not replace the name their other expenses carry.
    @Test("a blank member name never replaces a known one")
    func blankNameDoesNotWin() {
        let ledger = HouseholdLedger(budgets: [budget()], expenses: [
            expense("e1", amount: "10", member: "_a", name: "Alex", on: "2026-09-02T10:00:00Z"),
            expense("e2", amount: "5", member: "_a", name: "", on: "2026-09-12T10:00:00Z"),
        ])
        let totals = ledger.memberTotals(for: budget(), in: date("2026-09-20T00:00:00Z"), calendar: utc)
        #expect(totals.first?.name == "Alex")
        #expect(totals.first?.total == 15)
    }

    @Test("deleting a budget also finds its expenses")
    func budgetCascade() {
        let ledger = HouseholdLedger(budgets: [budget()], expenses: [
            expense("e1", amount: "1", member: "a", name: "A"),
            expense("e2", amount: "1", member: "a", name: "A", budgetID: "fuel"),
        ])
        #expect(ledger.expenseIDs(belongingTo: "groceries") == ["e1"])
    }

    // MARK: Permissions (M3.4.3)

    @Test("owners always edit; participants only with read-write; nobody outside")
    func accessRules() {
        #expect(HouseholdAccess.canEdit(role: .owner, permission: nil))
        #expect(HouseholdAccess.canEdit(role: .participant, permission: .readWrite))
        #expect(!HouseholdAccess.canEdit(role: .participant, permission: .readOnly))
        #expect(!HouseholdAccess.canEdit(role: .participant, permission: nil))
        #expect(!HouseholdAccess.canEdit(role: .none, permission: .readWrite))
    }

    // MARK: Offline cache

    /// The cache is what shows the household offline and what the engine
    /// resumes from; losing the zone or the share would orphan it.
    @Test("the cached snapshot keeps role, data, zone and share")
    func snapshotRoundTrip() throws {
        let share = CKShare(recordZoneID: zoneID)
        let snapshot = HouseholdPersistence.Snapshot(
            role: .owner,
            ledger: HouseholdLedger(budgets: [budget()], expenses: [expense("e1", amount: "12.34", member: "a", name: "A")]),
            zoneID: zoneID, memberID: "_me", engineState: nil, share: share
        )
        let decoded = try JSONDecoder().decode(
            HouseholdPersistence.Snapshot.self, from: JSONEncoder().encode(snapshot)
        )
        #expect(decoded.role == .owner)
        #expect(decoded.ledger == snapshot.ledger)
        #expect(decoded.zoneID == zoneID)
        #expect(decoded.memberID == "_me")
        #expect(decoded.share?.recordID == share.recordID)
    }
}
