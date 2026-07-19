import Testing
import SwiftData
import Foundation
import VittoraCore

/// Tier A: relocating the store into the App Group must not orphan 1.0 ledgers.
@Suite("ModelContainerConfig.appGroupStoreMigration", .serialized)
@MainActor
struct AppGroupStoreMigrationTests {

    @Test("legacy store present, no group store → data readable from group store after migration")
    func migratesLegacyStoreIntoGroupContainer() throws {
        try clearBothStoreLocations()
        defer { try? clearBothStoreLocations() }

        let accountID = UUID()
        let note = "legacy-ledger-row"
        try seedLegacyStore(accountID: accountID, note: note)

        #expect(FileManager.default.fileExists(atPath: ModelContainerConfig.legacyPersistentStoreURL.path))
        #expect(!FileManager.default.fileExists(atPath: ModelContainerConfig.persistentStoreURL.path))

        let didMigrate = try ModelContainerConfig.migrateLegacyStoreToGroupContainerIfNeeded()
        #expect(didMigrate)

        let container = try ModelContainerConfig.makeContainer(inMemory: false)
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDTransaction>())
        let migrated = try #require(rows.first { $0.note == note })
        #expect(migrated.accountID == accountID)
        // Fallback retained until a later cleanup — never delete on migrate.
        #expect(FileManager.default.fileExists(atPath: ModelContainerConfig.legacyPersistentStoreURL.path))
    }

    @Test("group store already present → legacy files untouched, no migration")
    func skipsMigrationWhenGroupStoreExists() throws {
        try clearBothStoreLocations()
        defer { try? clearBothStoreLocations() }

        let groupMarker = Data("group-store-marker".utf8)
        let legacyMarker = Data("legacy-store-marker".utf8)
        try writeStubStore(at: ModelContainerConfig.persistentStoreURL, contents: groupMarker)
        try writeStubStore(at: ModelContainerConfig.legacyPersistentStoreURL, contents: legacyMarker)

        let legacyBefore = try FileManager.default.attributesOfItem(
            atPath: ModelContainerConfig.legacyPersistentStoreURL.path
        )
        let legacyModBefore = legacyBefore[.modificationDate] as? Date

        let didMigrate = try ModelContainerConfig.migrateLegacyStoreToGroupContainerIfNeeded()
        #expect(!didMigrate)

        let legacyContents = try Data(contentsOf: ModelContainerConfig.legacyPersistentStoreURL)
        #expect(legacyContents == legacyMarker)
        let groupContents = try Data(contentsOf: ModelContainerConfig.persistentStoreURL)
        #expect(groupContents == groupMarker)

        let legacyAfter = try FileManager.default.attributesOfItem(
            atPath: ModelContainerConfig.legacyPersistentStoreURL.path
        )
        #expect(legacyAfter[.modificationDate] as? Date == legacyModBefore)
    }

    @Test("neither store present → clean first launch, no error")
    func cleanFirstLaunchWhenNeitherStoreExists() throws {
        try clearBothStoreLocations()
        defer { try? clearBothStoreLocations() }

        let didMigrate = try ModelContainerConfig.migrateLegacyStoreToGroupContainerIfNeeded()
        #expect(!didMigrate)

        let container = try ModelContainerConfig.makeContainer(inMemory: false)
        #expect(!container.configurations.isEmpty)
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.isEmpty)
    }

    @Test("migration runs exactly once (second call is a no-op)")
    func migrationIsIdempotent() throws {
        try clearBothStoreLocations()
        defer { try? clearBothStoreLocations() }

        try seedLegacyStore(accountID: UUID(), note: "idempotent-seed")

        let first = try ModelContainerConfig.migrateLegacyStoreToGroupContainerIfNeeded()
        #expect(first)
        #expect(FileManager.default.fileExists(atPath: ModelContainerConfig.persistentStoreURL.path))

        let second = try ModelContainerConfig.migrateLegacyStoreToGroupContainerIfNeeded()
        #expect(!second)
        // Legacy fallback still present after both calls.
        #expect(FileManager.default.fileExists(atPath: ModelContainerConfig.legacyPersistentStoreURL.path))
    }

    // MARK: - Helpers

    private func clearBothStoreLocations() throws {
        try ModelContainerConfig.destroyPersistentStore()
    }

    private func writeStubStore(at storeURL: URL, contents: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
            try contents.write(to: url)
        }
    }

    private func seedLegacyStore(accountID: UUID, note: String) throws {
        let schema = Schema(ModelContainerConfig.allModels)
        let config = ModelConfiguration(
            schema: schema,
            url: ModelContainerConfig.legacyPersistentStoreURL,
            cloudKitDatabase: .none
        )
        try FileManager.default.createDirectory(
            at: config.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = ModelContext(container)
            ctx.insert(SDTransaction(
                amount: 42,
                note: note,
                type: .expense,
                accountID: accountID,
                externalID: UUID().uuidString
            ))
            try ctx.save()
        }
        // Ensure WAL is checkpointed into the main file before we copy sidecars.
        #expect(FileManager.default.fileExists(atPath: ModelContainerConfig.legacyPersistentStoreURL.path))
    }
}
