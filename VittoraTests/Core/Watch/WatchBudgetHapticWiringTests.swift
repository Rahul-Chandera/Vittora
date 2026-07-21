#if os(iOS)
import Foundation
import Testing
import VittoraCore

@Suite("Watch budget haptic wiring", .serialized)
@MainActor
struct WatchBudgetHapticWiringTests {
    @Test("snapshot receive path deduplicates thresholds and resets for a new period")
    func receivePathDeduplicatesAndResets() throws {
        let suiteName = "WatchBudgetHapticWiringTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        var played: [BudgetAlertThreshold] = []
        let store = WatchSnapshotStore(
            cache: WatchSnapshotCache(fileURL: cacheURL),
            defaults: defaults,
            playHaptic: { played.append($0) }
        )

        store.applySnapshot(snapshot(spent: 74, period: "2026-07"))
        store.applySnapshot(snapshot(spent: 91, period: "2026-07"))
        #expect(played == [.ninety])

        let relaunchedStore = WatchSnapshotStore(
            cache: WatchSnapshotCache(fileURL: cacheURL),
            defaults: defaults,
            playHaptic: { played.append($0) }
        )
        relaunchedStore.applySnapshot(snapshot(spent: 91, period: "2026-07"))
        #expect(played == [.ninety])

        relaunchedStore.applySnapshot(snapshot(spent: 74, period: "2026-08"))
        relaunchedStore.applySnapshot(snapshot(spent: 91, period: "2026-08"))
        #expect(played == [.ninety, .ninety])
    }

    private func snapshot(spent: Decimal, period: String) -> WatchSnapshot {
        WatchSnapshot(
            todaySpend: 0,
            budgetSpent: spent,
            budgetTotal: 100,
            budgetPeriodKey: period,
            recentTransactions: [],
            currencyCode: "USD"
        )
    }
}
#endif
