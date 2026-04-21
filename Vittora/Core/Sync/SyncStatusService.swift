import Foundation
import Network
import CloudKit

enum SyncState: Equatable, Sendable {
    case synced
    case syncing
    case pending
    case offline
    case error(String)

    var displayText: String {
        switch self {
        case .synced:        return String(localized: "Synced")
        case .syncing:       return String(localized: "Syncing…")
        case .pending:       return String(localized: "Pending")
        case .offline:       return String(localized: "Offline")
        case .error(let msg): return String(localized: "Error: \(msg)")
        }
    }

    var systemImage: String {
        switch self {
        case .synced:  return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .pending: return "icloud.fill"
        case .offline: return "icloud.slash.fill"
        case .error:   return "exclamationmark.icloud.fill"
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

/// Offline contract:
/// - Local SwiftData writes must not be blocked by network or iCloud availability.
/// - CloudKit sync runs opportunistically when network and account access return.
/// - NSPersistentCloudKitContainer applies last-writer-wins conflict resolution by
///   modification timestamp; ambiguous merge events are surfaced in the sync log.
@Observable
@MainActor
final class SyncStatusService: Sendable {
    private(set) var syncState: SyncState = .synced
    private(set) var lastSyncDate: Date?
    private(set) var iCloudAccountAvailable: Bool = false

    private let userDefaults: UserDefaults
    private let pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "vittora.network.monitor", qos: .utility)
    private var isNetworkAvailable: Bool = true

    init(isMonitoringEnabled: Bool = true, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.lastSyncDate = userDefaults.object(forKey: "vittora.lastSyncDate") as? Date
        if isMonitoringEnabled {
            let monitor = NWPathMonitor()
            pathMonitor = monitor
            startNetworkMonitor(monitor)
        } else {
            pathMonitor = nil
        }
    }

    // MARK: - Network monitoring

    private func startNetworkMonitor(_ monitor: NWPathMonitor) {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if !self.isNetworkAvailable {
                    self.syncState = .offline
                } else if !wasAvailable && self.isNetworkAvailable {
                    // Came back online — re-check iCloud
                    await self.checkiCloudStatus()
                    if self.syncState == .offline {
                        self.syncState = .pending
                    }
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - iCloud status

    func checkiCloudStatus() async {
        // CKContainer crashes in test environments — skip CloudKit entirely
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        guard CloudKitRuntimeSupport.isEnabled else {
            iCloudAccountAvailable = false
            syncState = .error(CloudKitRuntimeSupport.unavailableMessage)
            return
        }

        guard isNetworkAvailable else {
            syncState = .offline
            return
        }

        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                iCloudAccountAvailable = true
                if case .error = syncState { /* leave error state as-is */ }
                else if syncState == .offline { syncState = .pending }
                else if syncState == .pending { /* stay pending until confirmed synced */ }
            case .noAccount:
                iCloudAccountAvailable = false
                syncState = .error(String(localized: "No iCloud account. Sign in to Settings → Apple ID."))
            case .restricted:
                iCloudAccountAvailable = false
                syncState = .error(String(localized: "iCloud access is restricted on this device."))
            case .couldNotDetermine:
                iCloudAccountAvailable = false
                syncState = .error(String(localized: "Could not determine iCloud status."))
            case .temporarilyUnavailable:
                iCloudAccountAvailable = false
                syncState = .error(String(localized: "iCloud is temporarily unavailable."))
            @unknown default:
                iCloudAccountAvailable = false
            }
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    // MARK: - Manual sync signals

    func markSyncing() {
        guard isNetworkAvailable && iCloudAccountAvailable else { return }
        syncState = .syncing
    }

    func markSynced() {
        let now = Date.now
        lastSyncDate = now
        userDefaults.set(now, forKey: "vittora.lastSyncDate")
        syncState = .synced
    }

    func markPending() {
        if isNetworkAvailable && iCloudAccountAvailable {
            syncState = .pending
        }
    }

    func markError(_ message: String) {
        syncState = .error(message)
    }

    // MARK: - Formatted last sync

    var lastSyncFormatted: String {
        guard let date = lastSyncDate else {
            return String(localized: "Never")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
