import Foundation
import Observation
import WatchConnectivity
import WidgetKit
import VittoraCore

/// Last phone snapshot cached on-watch for offline glances. No money writes.
@Observable
@MainActor
final class WatchSnapshotStore: NSObject {
    private(set) var snapshot: WatchSnapshot?
    private(set) var pendingExpense: QueuedWatchExpense?
    private(set) var isPhoneReachable = false
    private(set) var lastErrorMessage: String?

    private let cache: WatchSnapshotCache?
    private let pendingURL: URL
    private let session: WCSession

    init(
        cache: WatchSnapshotCache? = try? .watchAppGroup(),
        pendingURL: URL = WatchSnapshotStore.defaultPendingURL(),
        session: WCSession = .default
    ) {
        self.cache = cache
        self.pendingURL = pendingURL
        self.session = session
        super.init()
        snapshot = cache?.load()
        pendingExpense = Self.loadPending(from: pendingURL)
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
        isPhoneReachable = session.isReachable
        applyReceivedContextIfPresent()
    }

    @discardableResult
    func enqueueExpense(amount: Decimal, categoryID: UUID?) -> Bool {
        guard amount > 0 else {
            lastErrorMessage = String(localized: "Amount must be greater than zero")
            return false
        }
        guard WCSession.isSupported() else {
            lastErrorMessage = String(localized: "Watch connectivity is unavailable.")
            return false
        }
        let payload = QueuedWatchExpense(amount: amount, categoryID: categoryID)
        pendingExpense = payload
        try? payload.encodeForTransport().write(to: pendingURL, options: [.atomic])
        _ = session.transferUserInfo(payload.userInfoDictionary())
        isPhoneReachable = session.isReachable
        lastErrorMessage = nil
        return true
    }

    private func applyReceivedContextIfPresent() {
        let context = session.receivedApplicationContext
        guard let data = context[WatchConnectivityPayloadKey.snapshotData] as? Data else { return }
        applySnapshotData(data)
    }

    private func applySnapshotData(_ data: Data) {
        do {
            let decoded = try WatchSnapshot.decodeFromTransport(data)
            snapshot = decoded
            guard let cache else { throw CocoaError(.fileNoSuchFile) }
            try cache.save(decoded)
            WidgetCenter.shared.reloadAllTimelines()
            clearPendingIfConfirmed(by: decoded)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
    private static func defaultPendingURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("watch-pending-expense.json", isDirectory: false)
    }

    private static func loadPending(from url: URL) -> QueuedWatchExpense? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? QueuedWatchExpense.decodeFromTransport(data)
    }

    private func clearPendingIfConfirmed(by snapshot: WatchSnapshot) {
        guard let pendingExpense else { return }
        let matchingTransaction = snapshot.recentTransactions.contains { transaction in
            transaction.type == .expense
                && transaction.amount == pendingExpense.amount
                && transaction.categoryID == pendingExpense.categoryID
                && transaction.date >= pendingExpense.createdAt.addingTimeInterval(-1)
        }
        guard matchingTransaction else { return }
        self.pendingExpense = nil
        try? FileManager.default.removeItem(at: pendingURL)
    }
}

extension WatchSnapshotStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            applyReceivedContextIfPresent()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[WatchConnectivityPayloadKey.snapshotData] as? Data else { return }
        Task { @MainActor in
            applySnapshotData(data)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            isPhoneReachable = isReachable
        }
    }
}
