#if os(iOS)
import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("WatchBridgeService", .serialized)
@MainActor
struct WatchBridgeServiceTests {

    @Test("invalid queued payload surfaces error and does not commit")
    func invalidPayloadSurfacesErrorWithoutCommit() async {
        let session = FakeWatchSessionClient()
        var presented: String?
        var commitCount = 0

        let bridge = WatchBridgeService(
            session: session,
            buildSnapshot: {
                WatchSnapshot(
                    todaySpend: 0,
                    budgetSpent: 0,
                    budgetTotal: 0,
                    recentTransactions: [],
                    currencyCode: "USD"
                )
            },
            commitExpense: { _ in
                commitCount += 1
            },
            presentError: { message in
                presented = message
            }
        )

        await bridge.handleIncomingUserInfo([
            WatchConnectivityPayloadKey.payloadType: WatchConnectivityPayloadKey.queuedExpense,
            WatchConnectivityPayloadKey.amount: "0",
        ])

        #expect(commitCount == 0)
        #expect(presented != nil)
        #expect(presented?.isEmpty == false)
    }

    @Test("valid queued payload commits through injected use-case path")
    func validPayloadCommits() async throws {
        let session = FakeWatchSessionClient()
        var committed: QueuedWatchExpense?
        var presented: String?

        let bridge = WatchBridgeService(
            session: session,
            buildSnapshot: {
                WatchSnapshot(
                    todaySpend: 1,
                    budgetSpent: 1,
                    budgetTotal: 10,
                    recentTransactions: [],
                    currencyCode: "USD"
                )
            },
            commitExpense: { expense in
                committed = expense
            },
            presentError: { message in
                presented = message
            }
        )

        let amount = Decimal(string: "12.50") ?? 0
        let categoryID = UUID()
        let payload = QueuedWatchExpense(amount: amount, categoryID: categoryID)
        await bridge.handleIncomingUserInfo(payload.userInfoDictionary())

        #expect(presented == nil)
        #expect(committed?.amount == amount)
        #expect(committed?.categoryID == categoryID)
    }

    @Test("commit failure surfaces error and does not pretend success")
    func commitFailureSurfacesError() async {
        let session = FakeWatchSessionClient()
        var presented: String?
        var notifyCount = 0

        let bridge = WatchBridgeService(
            session: session,
            buildSnapshot: {
                WatchSnapshot(
                    todaySpend: 0,
                    budgetSpent: 0,
                    budgetTotal: 0,
                    recentTransactions: [],
                    currencyCode: "USD"
                )
            },
            commitExpense: { _ in
                throw VittoraError.validationFailed("Category not found")
            },
            presentError: { message in
                presented = message
            },
            notifyCommitted: {
                notifyCount += 1
            }
        )

        let payload = QueuedWatchExpense(amount: Decimal(string: "9.99") ?? 0, categoryID: UUID())
        await bridge.handleIncomingUserInfo(payload.userInfoDictionary())

        #expect(notifyCount == 0)
        #expect(presented?.contains("Category not found") == true)
    }
}

@MainActor
private final class FakeWatchSessionClient: WatchSessionClient {
    var isSupported: Bool = true
    private(set) var contexts: [[String: Any]] = []
    private weak var delegate: (any WatchSessionClientDelegate)?

    func setDelegate(_ delegate: any WatchSessionClientDelegate) {
        self.delegate = delegate
    }

    func activate() {
        delegate?.watchSessionActivationDidComplete()
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        contexts.append(context)
    }
}
#endif
