import Foundation
import Observation
import WatchConnectivity
import WidgetKit
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
    private(set) var pendingExpense: QueuedWatchExpense?
    private(set) var isPhoneReachable = false
    private(set) var lastErrorMessage: String?
    private(set) var budgetAlert: BudgetAlertThreshold?

    private let cache: WatchSnapshotCache?
    private let pendingURL: URL
    private let session: WCSession
    private let defaults: UserDefaults
    private let playHaptic: @MainActor (BudgetAlertThreshold) -> Void
    @ObservationIgnored private var dismissAlertTask: Task<Void, Never>?

    private static let notifiedPeriodKey = "watchBudgetNotifiedPeriod"
    private static let notifiedThresholdKey = "watchBudgetNotifiedThreshold"

    init(
        cache: WatchSnapshotCache? = try? .watchAppGroup(),
        pendingURL: URL = WatchSnapshotStore.defaultPendingURL(),
        session: WCSession = .default,
        defaults: UserDefaults = .standard,
        playHaptic: @escaping @MainActor (BudgetAlertThreshold) -> Void = { _ in }
    ) {
        self.cache = cache
        self.pendingURL = pendingURL
        self.session = session
        self.defaults = defaults
        self.playHaptic = playHaptic
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
            applySnapshot(decoded)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func applySnapshot(_ newSnapshot: WatchSnapshot) {
        let previousSnapshot = snapshot
        snapshot = newSnapshot
        notifyBudgetCrossing(from: previousSnapshot, to: newSnapshot)

        do {
            guard let cache else { throw CocoaError(.fileNoSuchFile) }
            try cache.save(newSnapshot)
            WidgetCenter.shared.reloadAllTimelines()
            clearPendingIfConfirmed(by: newSnapshot)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
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

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            isPhoneReachable = isReachable
        }
    }
}
