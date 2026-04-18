import SwiftData
import Foundation
import os

enum ModelContainerConfig {
    /// All SwiftData model types registered in the app
    static var allModels: [any PersistentModel.Type] {
        [
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDPayee.self,
            SDRecurringRule.self,
            SDDocument.self,
            SDDebt.self,
            SDSplitGroup.self,
            SDGroupExpense.self,
            SDTaxProfile.self,
            SDSavingsGoal.self,
        ]
    }

    /// Create the shared model container
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(allModels)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            inMemory || !CloudKitRuntimeSupport.isEnabled ? .none : .automatic
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        if !inMemory {
            applyStoreFileAttributes(to: container)
        }
        return container
    }

    /// In-memory container for previews and tests
    static func makePreviewContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    // MARK: - Store file hardening

    private static let logger = Logger(subsystem: "com.vittora.app", category: "Persistence")

    /// Applies .completeUnlessOpen file protection and excludes the store from iCloud
    /// backups (data is already in iCloud via CloudKit sync).
    /// Called on every launch so existing stores are upgraded on first run after update.
    private static func applyStoreFileAttributes(to container: ModelContainer) {
        let fm = FileManager.default
        for configuration in container.configurations {
            let storeURL = configuration.url
            // SQLite WAL mode creates companion -wal and -shm sidecar files.
            let urls = [
                storeURL,
                URL(fileURLWithPath: storeURL.path + "-wal"),
                URL(fileURLWithPath: storeURL.path + "-shm"),
            ]
            for url in urls {
                guard fm.fileExists(atPath: url.path) else { continue }
                do {
                    #if os(iOS)
                    // .completeUnlessOpen: encrypted when closed, accessible
                    // while the store is open (needed for background CloudKit sync).
                    try fm.setAttributes(
                        [.protectionKey: FileProtectionType.completeUnlessOpen],
                        ofItemAtPath: url.path
                    )
                    #endif
                    // Exclude from device backup: CloudKit is the sync/restore
                    // mechanism; local backup would double-store encrypted data.
                    var mutableURL = url
                    var backupValues = URLResourceValues()
                    backupValues.isExcludedFromBackup = true
                    try mutableURL.setResourceValues(backupValues)
                } catch {
                    logger.error(
                        "Store file attribute error on \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }
}
