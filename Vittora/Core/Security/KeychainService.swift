import Foundation
import Security

enum KeychainItemAccess: Sendable, Equatable {
    case standard
    case biometricBound
}

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String, access: KeychainItemAccess) async throws
    func load(forKey key: String, access: KeychainItemAccess) async throws -> Data?
    func delete(forKey key: String) async throws
    func exists(forKey key: String) async throws -> Bool
}

extension KeychainServiceProtocol {
    func save(_ data: Data, forKey key: String) async throws {
        try await save(data, forKey: key, access: .standard)
    }

    func load(forKey key: String) async throws -> Data? {
        try await load(forKey: key, access: .standard)
    }
}

@MainActor
final class KeychainService: KeychainServiceProtocol, Sendable {
    private let serviceName = "com.vittora.keychain"

    func save(_ data: Data, forKey key: String, access: KeychainItemAccess) async throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        var query = baseQuery
        query[kSecValueData as String] = data

        switch access {
        case .standard:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .biometricBound:
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            ) else {
                throw VittoraError.encryptionFailed(
                    String(localized: "Failed to create secure Keychain access control.")
                )
            }
            query[kSecAttrAccessControl as String] = accessControl
        }

        SecItemDelete(baseQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to save data to Keychain: \(status)")
            )
        }
    }

    func load(forKey key: String, access: KeychainItemAccess) async throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        if access == .biometricBound {
            query[kSecUseOperationPrompt as String] = String(
                localized: "Authenticate to access your encrypted Vittora data."
            )
        }

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
