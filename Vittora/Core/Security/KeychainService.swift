import Foundation
import Security

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String) async throws
    func load(forKey key: String) async throws -> Data?
    func delete(forKey key: String) async throws
    func exists(forKey key: String) async throws -> Bool
}

@MainActor
final class KeychainService: KeychainServiceProtocol, Sendable {
    private let serviceName = "com.vittora.keychain"

    func save(_ data: Data, forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to save data to Keychain: \(status)")
            )
        }
    }

    func load(forKey key: String) async throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VittoraError.encryptionFailed(
                    String(localized: "Invalid data format in Keychain")
                )
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to load data from Keychain: \(status)")
            )
        }
    }

    func delete(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to delete data from Keychain: \(status)")
            )
        }
    }

    func exists(forKey key: String) async throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
