import Foundation
import Security
import VittoraCore

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
                throw SecurityErrorMapper.encryptionFailed(.keychainAccessControl)
            }
            query[kSecAttrAccessControl as String] = accessControl
        }

        SecItemDelete(baseQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityErrorMapper.encryptionFailed(.keychainSave, osStatus: status, key: key)
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
                throw SecurityErrorMapper.encryptionFailed(.keychainLoad, key: key)
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw SecurityErrorMapper.encryptionFailed(.keychainLoad, osStatus: status, key: key)
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
            throw SecurityErrorMapper.encryptionFailed(.keychainDelete, osStatus: status, key: key)
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

    // MARK: - Synchronous helpers (for use in init/startup code that cannot be async)

    nonisolated static func syncLoad(
        forKey key: String,
        service: String = "com.vittora.keychain"
    ) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    nonisolated static func syncSave(
        _ data: Data,
        forKey key: String,
        service: String = "com.vittora.keychain"
    ) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemDelete(baseQuery as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    nonisolated static func syncDelete(
        forKey key: String,
        service: String = "com.vittora.keychain"
    ) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    nonisolated static func syncLoadBool(forKey key: String) -> Bool {
        syncLoad(forKey: key).map { $0.first == 1 } ?? false
    }

    nonisolated static func syncLoadString(forKey key: String) -> String? {
        syncLoad(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }
}
