import Foundation
import Observation
import WatchConnectivity
import VittoraCore

/// Last phone snapshot cached on-watch for offline glances. No money writes.
@Observable
@MainActor
final class WatchSnapshotStore: NSObject {
    private(set) var snapshot: WatchSnapshot?
    private(set) var lastErrorMessage: String?

    private let fileURL: URL
    private let session: WCSession

    init(
        fileURL: URL = WatchSnapshotStore.defaultCacheURL(),
        session: WCSession = .default
    ) {
        self.fileURL = fileURL
        self.session = session
        super.init()
        snapshot = Self.loadCache(from: fileURL)
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
            try Self.writeCache(decoded, to: fileURL)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private static func defaultCacheURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("watch-snapshot.json", isDirectory: false)
    }

    private static func loadCache(from url: URL) -> WatchSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? WatchSnapshot.decodeFromTransport(data)
    }

    private static func writeCache(_ snapshot: WatchSnapshot, to url: URL) throws {
        let data = try snapshot.encodeForTransport()
        try data.write(to: url, options: [.atomic])
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
