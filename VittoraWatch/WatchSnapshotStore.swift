import Foundation
import Observation
import WatchConnectivity
import VittoraCore

enum BudgetAlertThreshold: Int, CaseIterable, Sendable {
    case seventyFive = 75
    case ninety = 90
    case oneHundred = 100
}

/// Last phone snapshot cached on-watch for offline glances. No money writes.
@Observable
@MainActor
final class WatchSnapshotStore: NSObject {
    private(set) var snapshot: WatchSnapshot?
    private(set) var lastErrorMessage: String?
    private(set) var budgetAlert: BudgetAlertThreshold?

    private let fileURL: URL
    private let session: WCSession
    private let defaults: UserDefaults
    private let playHaptic: @MainActor (BudgetAlertThreshold) -> Void
    @ObservationIgnored private var dismissAlertTask: Task<Void, Never>?

    private static let notifiedPeriodKey = "watchBudgetNotifiedPeriod"
    private static let notifiedThresholdKey = "watchBudgetNotifiedThreshold"

    init(
        fileURL: URL = WatchSnapshotStore.defaultCacheURL(),
        session: WCSession = .default,
        defaults: UserDefaults = .standard,
        playHaptic: @escaping @MainActor (BudgetAlertThreshold) -> Void = { _ in }
    ) {
        self.fileURL = fileURL
        self.session = session
        self.defaults = defaults
        self.playHaptic = playHaptic
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
            applySnapshot(decoded)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func applySnapshot(_ newSnapshot: WatchSnapshot) {
        let previousSnapshot = snapshot
        snapshot = newSnapshot

        do {
            try Self.writeCache(newSnapshot, to: fileURL)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        notifyBudgetCrossing(from: previousSnapshot, to: newSnapshot)
    }

    private func notifyBudgetCrossing(
        from previousSnapshot: WatchSnapshot?,
        to newSnapshot: WatchSnapshot
    ) {
        let storedPeriod = defaults.string(forKey: Self.notifiedPeriodKey)
        if storedPeriod != newSnapshot.budgetPeriodKey {
            defaults.set(newSnapshot.budgetPeriodKey, forKey: Self.notifiedPeriodKey)
            defaults.removeObject(forKey: Self.notifiedThresholdKey)
        }

        guard let previousSnapshot,
              previousSnapshot.budgetPeriodKey == newSnapshot.budgetPeriodKey,
              previousSnapshot.budgetTotal > 0,
              newSnapshot.budgetTotal > 0 else {
            return
        }

        let lastNotified = defaults.integer(forKey: Self.notifiedThresholdKey)
        let crossed = BudgetAlertThreshold.allCases.last { threshold in
            threshold.rawValue > lastNotified
                && previousSnapshot.budgetSpent * 100
                    < previousSnapshot.budgetTotal * Decimal(threshold.rawValue)
                && newSnapshot.budgetSpent * 100
                    >= newSnapshot.budgetTotal * Decimal(threshold.rawValue)
        }
        guard let crossed else { return }

        defaults.set(crossed.rawValue, forKey: Self.notifiedThresholdKey)
        budgetAlert = crossed
        playHaptic(crossed)

        dismissAlertTask?.cancel()
        dismissAlertTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, self?.budgetAlert == crossed else { return }
            self?.budgetAlert = nil
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
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

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
