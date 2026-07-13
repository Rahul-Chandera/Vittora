import Testing
import Foundation
import VittoraCore

/// Recovery-mode factory reset must delete the unopenable on-disk store (and
/// its SQLite sidecars) or the next launch lands straight back in recovery —
/// the repositories only ever clear the in-memory recovery container.
@Suite("ModelContainerConfig.destroyPersistentStore")
struct StoreDestructionTests {

    @Test("removes the store file and its WAL/SHM sidecars")
    func destroysStoreAndSidecars() throws {
        let storeURL = ModelContainerConfig.persistentStoreURL
        let fm = FileManager.default
        try fm.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let paths = [storeURL.path, storeURL.path + "-wal", storeURL.path + "-shm"]
        for path in paths where !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: Data("stub".utf8))
        }

        try ModelContainerConfig.destroyPersistentStore()

        for path in paths {
            #expect(!fm.fileExists(atPath: path), "\(path) should be deleted")
        }
    }
}
