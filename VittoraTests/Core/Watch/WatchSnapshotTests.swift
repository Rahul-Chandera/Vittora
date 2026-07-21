import Foundation
import Testing
import VittoraCore

@Suite("WatchSnapshot")
struct WatchSnapshotTests {

    @Test("500 crown steps of 50 cents equal exactly 250.00")
    func crownStepsRemainExact() {
        var amount = WatchExpenseAmount()
        amount.applyCrownSteps(500)

        #expect(amount.cents == 25_000)
        #expect(amount.decimal == Decimal(string: "250.00"))
    }

    @Test("encode/decode round-trip preserves Decimal precision")
    func roundTripPreservesDecimal() throws {
        let amount = Decimal(string: "15.49") ?? 0
        let spent = Decimal(string: "42.5") ?? 0
        let total = Decimal(string: "100.00") ?? 0
        let snapshot = WatchSnapshot(
            todaySpend: amount,
            budgetSpent: spent,
            budgetTotal: total,
            recentTransactions: [
                WatchSnapshotTransaction(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    name: "Coffee",
                    amount: Decimal(string: "4.50") ?? 0,
                    type: .expense
                ),
            ],
            currencyCode: "USD",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let data = try snapshot.encodeForTransport()
        let decoded = try WatchSnapshot.decodeFromTransport(data)

        #expect(decoded.todaySpend == amount)
        #expect(decoded.budgetSpent == spent)
        #expect(decoded.budgetTotal == total)
        #expect(decoded.budgetRemaining == total - spent)
        #expect(decoded.currencyCode == "USD")
        #expect(decoded.recentTransactions.count == 1)
        #expect(decoded.recentTransactions[0].amount == Decimal(string: "4.50"))
        #expect(decoded.recentTransactions[0].name == "Coffee")
        #expect(decoded.generatedAt == snapshot.generatedAt)
    }

    @Test("snapshot caps quick categories at eight")
    func capsQuickCategories() {
        let categories = (0..<10).map { index in
            WatchSnapshotCategory(
                id: UUID(),
                name: "Category \(index)",
                icon: "tag",
                colorHex: "#007AFF"
            )
        }
        let snapshot = WatchSnapshot(
            todaySpend: 0,
            budgetSpent: 0,
            budgetTotal: 0,
            recentTransactions: [],
            quickCategories: categories,
            currencyCode: "USD"
        )

        #expect(snapshot.quickCategories.count == 8)
    }

    @Test("caps recent transactions at 10")
    func capsRecentTransactions() {
        let txs = (0..<15).map { i in
            WatchSnapshotTransaction(
                date: .now,
                name: "T\(i)",
                amount: Decimal(i + 1),
                type: .expense
            )
        }
        let snapshot = WatchSnapshot(
            todaySpend: 1,
            budgetSpent: 1,
            budgetTotal: 10,
            recentTransactions: txs,
            currencyCode: "USD"
        )
        #expect(snapshot.recentTransactions.count == 10)
    }

    @Test("encoded snapshot stays under application-context size limit")
    func encodedSizeUnderLimit() throws {
        let txs = (0..<10).map { i in
            WatchSnapshotTransaction(
                date: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)),
                name: String(repeating: "Purchase ", count: 8) + "\(i)",
                amount: Decimal(string: "123.45") ?? 0,
                type: .expense
            )
        }
        let snapshot = WatchSnapshot(
            todaySpend: Decimal(string: "999.99") ?? 0,
            budgetSpent: Decimal(string: "1500.00") ?? 0,
            budgetTotal: Decimal(string: "2000.00") ?? 0,
            recentTransactions: txs,
            currencyCode: "USD"
        )
        let data = try snapshot.encodeForTransport()
        // WCSession application context limit is ~65KB.
        #expect(data.count < 65_000)
    }

    @Test("queued expense userInfo round-trip preserves Decimal")
    func queuedExpenseUserInfoRoundTrip() throws {
        let amount = Decimal(string: "27.35") ?? 0
        let categoryID = UUID()
        let expense = QueuedWatchExpense(
            amount: amount,
            categoryID: categoryID,
            createdAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let decoded = try QueuedWatchExpense.fromUserInfo(expense.userInfoDictionary())
        #expect(decoded.amount == amount)
        #expect(decoded.categoryID == categoryID)
    }

    @Test("complication snapshot becomes stale only after 24 hours")
    func complicationStalenessUsesInjectedDate() {
        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = WatchSnapshot(
            todaySpend: 42,
            budgetSpent: 250,
            budgetTotal: 1_000,
            recentTransactions: [],
            currencyCode: "USD",
            generatedAt: generatedAt
        )

        #expect(!snapshot.isStale(at: generatedAt.addingTimeInterval(24 * 60 * 60)))
        #expect(snapshot.isStale(at: generatedAt.addingTimeInterval(24 * 60 * 60 + 1)))
    }

    @Test("watch complication cache reads the snapshot written by the watch app path")
    func complicationCacheWiringRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = WatchSnapshotCache(
            fileURL: directory.appendingPathComponent("watch-snapshot.json")
        )
        let snapshot = WatchSnapshot(
            todaySpend: Decimal(string: "15.49") ?? 0,
            budgetSpent: 250,
            budgetTotal: 1_000,
            recentTransactions: [],
            currencyCode: "USD",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try cache.save(snapshot)

        #expect(cache.load() == snapshot)
    }

    @Test("invalid queued amount fails without producing an expense")
    func invalidQueuedAmountThrows() {
        let info: [String: Any] = [
            WatchConnectivityPayloadKey.payloadType: WatchConnectivityPayloadKey.queuedExpense,
            WatchConnectivityPayloadKey.amount: "not-a-number",
        ]
        #expect(throws: (any Error).self) {
            _ = try QueuedWatchExpense.fromUserInfo(info)
        }
    }
}
