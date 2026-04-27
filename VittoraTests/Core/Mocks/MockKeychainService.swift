import Foundation
@testable import Vittora

@MainActor
final class MockKeychainService: KeychainServiceProtocol, Sendable {
    private var storage: [String: Data] = [:]
    var shouldThrowError = false
    var throwError: VittoraError = .encryptionFailed(String(localized: "Mock error"))

    func save(_ data: Data, forKey key: String, access: KeychainItemAccess) async throws {
        if shouldThrowError { throw throwError }
        storage[key] = data
    }

    func load(forKey key: String, access: KeychainItemAccess) async throws -> Data? {
        if shouldThrowError { throw throwError }
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
        shouldThrowError = false
    }
}
