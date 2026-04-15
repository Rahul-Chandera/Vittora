import Foundation
import CoreData

@MainActor
final class CloudKitSyncMonitor {
    private let syncStatusService: SyncStatusService
    private let conflictHandler: SyncConflictHandler
    private let notificationCenter: NotificationCenter
    private var eventObserver: NSObjectProtocol?

    init(
        syncStatusService: SyncStatusService,
        conflictHandler: SyncConflictHandler,
        notificationCenter: NotificationCenter = .default
    ) {
        self.syncStatusService = syncStatusService
        self.conflictHandler = conflictHandler
        self.notificationCenter = notificationCenter
        startObserving()
    }

    deinit {
        if let eventObserver {
            notificationCenter.removeObserver(eventObserver)
        }
    }

    private func startObserving() {
        eventObserver = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            syncStatusService.markSyncing()
            return
        }

        guard let error = event.error else {
            syncStatusService.markSynced()
            return
        }

        if isConflictError(error) {
            _ = conflictHandler.logConflict(
                entityType: event.type.vittoraDisplayName,
                localTimestamp: event.startDate,
                remoteTimestamp: event.endDate ?? .now,
                description: conflictDescription(for: event.type, error: error)
            )
            PerformanceLogger.Sync.conflict()
            syncStatusService.markError(String(localized: "A sync conflict was resolved automatically. Review iCloud Sync for details."))
            return
        }

        syncStatusService.markError(error.localizedDescription)
    }

    private func isConflictError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let detail = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion,
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        return detail.contains("conflict")
            || detail.contains("merge")
            || detail.contains("server record changed")
    }

    private func conflictDescription(
        for eventType: NSPersistentCloudKitContainer.EventType,
        error: Error
    ) -> String {
        "\(eventType.vittoraDisplayName): \(error.localizedDescription)"
    }
}

private extension NSPersistentCloudKitContainer.EventType {
    var vittoraDisplayName: String {
        switch self {
        case .setup:
            String(localized: "Setup")
        case .import:
            String(localized: "Import")
        case .export:
            String(localized: "Export")
        @unknown default:
            String(localized: "Sync")
        }
    }
}
