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
    private(set) var lastErrorMessage: String?

    private let cache: WatchSnapshotCache?
    private let session: WCSession

    init(
        cache: WatchSnapshotCache? = try? .watchAppGroup(),
        session: WCSession = .default
    ) {
        self.cache = cache
        self.session = session
        super.init()
        snapshot = cache?.load()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
        applyReceivedContextIfPresent()
    }

    func enqueueExpense(amount: Decimal, categoryID: UUID?) {
        guard amount > 0 else {
            lastErrorMessage = String(localized: "Amount must be greater than zero")
            return
        }
        guard WCSession.isSupported() else {
            lastErrorMessage = String(localized: "Watch connectivity is unavailable.")
            return
        }
        let payload = QueuedWatchExpense(amount: amount, categoryID: categoryID)
        _ = session.transferUserInfo(payload.userInfoDictionary())
        lastErrorMessage = nil
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
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
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
}
