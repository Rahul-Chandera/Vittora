import Foundation
@testable import Vittora

@MainActor
final class MockKeychainService: KeychainServiceProtocol, Sendable {
    private var storage: [String: Data] = [:]
    private var saveCounts: [String: Int] = [:]
    var shouldThrowError = false
    var throwError: VittoraError = .encryptionFailed(String(localized: "Mock error"))
    /// Artificial delay on load to widen concurrent get-or-create races in tests.
    var loadDelayNanoseconds: UInt64 = 0

    func save(_ data: Data, forKey key: String, access: KeychainItemAccess) async throws {
        if shouldThrowError { throw throwError }
        storage[key] = data
        saveCounts[key, default: 0] += 1
    }

    func load(forKey key: String, access: KeychainItemAccess) async throws -> Data? {
        if shouldThrowError { throw throwError }
        if loadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadDelayNanoseconds)
        }
        return storage[key]
    }

    func delete(forKey key: String) async throws {
        if shouldThrowError { throw throwError }
        storage.removeValue(forKey: key)
    }

    func exists(forKey key: String) async throws -> Bool {
        if shouldThrowError { throw throwError }
        return storage[key] != nil
    }

    func reset() {
        storage.removeAll()
        saveCounts.removeAll()
        shouldThrowError = false
        loadDelayNanoseconds = 0
    }

    func saveCount(forKey key: String) -> Int {
        saveCounts[key, default: 0]
    }
}
