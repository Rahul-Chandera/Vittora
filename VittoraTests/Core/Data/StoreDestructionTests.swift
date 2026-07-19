import Testing
import Foundation
import VittoraCore

/// Recovery-mode factory reset must delete the unopenable on-disk store (and
/// its SQLite sidecars) or the next launch lands straight back in recovery —
/// the repositories only ever clear the in-memory recovery container.
@Suite("ModelContainerConfig.destroyPersistentStore")
struct StoreDestructionTests {

    @Test("removes the store file and its WAL/SHM sidecars, including the legacy location")
    func destroysStoreAndSidecars() throws {
        let fm = FileManager.default
        var storeURLs = [ModelContainerConfig.persistentStoreURL]
        // A leftover 1.0 app-container store is re-copied into the group on
        // next launch when the group store is missing, so destroy covers both.
        let legacyURL = ModelContainerConfig.legacyPersistentStoreURL
        if legacyURL != ModelContainerConfig.persistentStoreURL {
            storeURLs.append(legacyURL)
        }

        var paths: [String] = []
        for storeURL in storeURLs {
            try fm.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            for suffix in ["", "-wal", "-shm"] {
                paths.append(storeURL.path + suffix)
            }
        }
        for path in paths where !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: Data("stub".utf8))
        }

        try ModelContainerConfig.destroyPersistentStore()

        for path in paths {
            #expect(!fm.fileExists(atPath: path), "\(path) should be deleted")
        }
    }
}
