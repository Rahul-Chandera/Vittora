import Foundation
import CoreData
import CloudKit

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
            // Entity modification timestamps are not surfaced by NSPersistentCloudKitContainer
            // events, so resolution is advisory only (.ambiguous). The system has already applied
            // its own LWW resolution before this handler fires.
            _ = conflictHandler.logConflict(
                entityType: event.type.vittoraDisplayName,
                detectedAt: event.endDate ?? .now,
                localModifiedAt: nil,
                remoteModifiedAt: nil,
                description: conflictDescription(for: event.type, error: error)
            )
            PerformanceLogger.Sync.conflict()
            syncStatusService.markError(String(localized: "A sync conflict was resolved automatically. Review iCloud Sync for details."))
            return
        }

        syncStatusService.markError(error.localizedDescription)
    }

    /// Returns true when the error chain contains a CKError indicating a record conflict.
    private func isConflictError(_ error: Error) -> Bool {
        guard let ckError = extractCKError(from: error) else { return false }
        switch ckError.code {
        case .serverRecordChanged:
            return true
        case .batchRequestFailed, .partialFailure:
            let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error]
            return partialErrors?.values.contains {
                (extractCKError(from: $0)?.code) == .serverRecordChanged
            } ?? false
        default:
            return false
        }
    }

    /// Walks the NSError `underlyingErrors` / `NSUnderlyingErrorKey` chain to find a CKError.
    private func extractCKError(from error: Error) -> CKError? {
        if let ck = error as? CKError { return ck }
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return extractCKError(from: underlying)
        }
        if let underlyingErrors = ns.userInfo[NSDetailedErrorsKey] as? [Error] {
            return underlyingErrors.lazy.compactMap { self.extractCKError(from: $0) }.first
        }
        return nil
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
