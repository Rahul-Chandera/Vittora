import SwiftData
import Foundation
import os

public enum ModelContainerConfig {
    /// All SwiftData model types registered in the app (current schema version).
    public nonisolated static var allModels: [any PersistentModel.Type] {
        VittoraSchemaV6.models
    }

    /// Create the shared model container using a versioned schema baseline.
    public nonisolated static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(allModels)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            inMemory || !CloudKitRuntimeSupport.isEnabled ? .none : .automatic
        // CloudKit sync is intentionally free for all users (DEC-008 / F0 Option A).
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: inMemory ? .none : .identifier(AppGroupConfiguration.identifier),
            cloudKitDatabase: cloudKitDatabase
        )
        if !inMemory {
            // On a fresh install the app-group container has no
            // Library/Application Support yet; without this, addPersistentStore
            // fails (Cocoa 512) and relies on CoreData's noisy error recovery
            // to create the directory on every first launch.
            ensureStoreDirectoryExists(for: config)
        }
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

    /// Opens the shared App Group store for extension processes: read-only,
    /// no migration plan, no CloudKit. The host app owns schema migrations.
    public nonisolated static func makeReadOnlyContainer() throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: false,
            groupContainer: .identifier(AppGroupConfiguration.identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// File URL of the on-disk store — the same one `makeContainer` opens.
    public nonisolated static var persistentStoreURL: URL {
        ModelConfiguration(
            schema: Schema(allModels),
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroupConfiguration.identifier),
            cloudKitDatabase: .none
        ).url
    }

    /// Deletes the on-disk store and its WAL/SHM sidecars so the next launch
    /// starts from a fresh store. Only safe while no on-disk container is open
    /// — i.e. recovery mode, where the store couldn't be opened at all (the
    /// escape hatch from an unopenable store, e.g. unknown model version).
    ///
    /// Also removes the legacy store in the app's own Application Support:
    /// SwiftData silently re-copies it (attributes intact) into the group
    /// container whenever the group store is missing, so deleting only the
    /// group store resurrects the broken legacy store on the next launch.
    public nonisolated static func destroyPersistentStore() throws {
        let fm = FileManager.default
        var storeURLs = [persistentStoreURL]
        if let legacyDirectory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let legacyURL = legacyDirectory.appendingPathComponent("default.store")
            if legacyURL != persistentStoreURL {
                storeURLs.append(legacyURL)
            }
        }
        for storeURL in storeURLs {
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            }
        }
    }

    /// In-memory container for previews and tests
    public nonisolated static func makePreviewContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    /// Ephemeral in-memory container for startup-failure DI wiring only.
    /// Skips the migration plan so a broken on-disk migration cannot block `StartupFailureView`.
    public static func makeEphemeralWiringContainer() throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates the store's parent directory (with intermediates) if missing.
    /// No-op when it already exists.
    nonisolated private static func ensureStoreDirectoryExists(for configuration: ModelConfiguration) {
        let directory = configuration.url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            // Non-fatal: CoreData's own recovery can still create it.
            logger.error(
                "Could not pre-create store directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Store file hardening

    nonisolated private static let logger = Logger(subsystem: "com.vittora.app", category: "Persistence")

    /// Applies .completeUnlessOpen file protection and excludes the store from iCloud
    /// backups (data is already in iCloud via CloudKit sync).
    /// Called on every launch so existing stores are upgraded on first run after update.
    nonisolated private static func applyStoreFileAttributes(to container: ModelContainer) {
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
