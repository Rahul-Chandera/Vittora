import Foundation
import CryptoKit
import Security

protocol EncryptionServiceProtocol: Sendable {
    func encrypt(_ data: Data) async throws -> Data
    func decrypt(_ encryptedData: Data) async throws -> Data
    func generateKey() async throws
}

/// AES-256-GCM encryption service.
///
/// On real devices the AES key is wrapped with an EC P-256 key that lives in
/// the Secure Enclave, so the raw AES bytes never leave hardware. On the
/// Simulator (no SE) the key falls back to a biometric-bound Keychain item.
@MainActor
final class EncryptionService: EncryptionServiceProtocol, Sendable {
    private let keychainService: any KeychainServiceProtocol

    /// Keychain item that stores the ECIES-wrapped AES key (device path).
    private let seWrappedKeyID = "com.vittora.encryption.key.se_wrapped"
    /// Keychain item for the raw AES key (simulator path / legacy).
    private let legacyKeyID = "com.vittora.encryption.key"
    /// SE key tag used as the `kSecAttrApplicationTag` search criterion.
    private let seKeyTag = Data("com.vittora.se.key".utf8)
    /// ECIES variant supported by the Secure Enclave.
    private let eciesAlgorithm =
        SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM

    init(keychainService: any KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

    // MARK: - Public interface

    func encrypt(_ data: Data) async throws -> Data {
        let key = try await getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to combine encryption components")
            )
        }
        return combined
    }

    func decrypt(_ encryptedData: Data) async throws -> Data {
        let key = try await getOrCreateKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to decrypt data: \(error.localizedDescription)")
            )
        }
    }

    /// Creates a new AES key (replacing any existing one) and persists it.
    /// On device the key is wrapped by a Secure Enclave EC key; on the
    /// Simulator it is stored as a biometric-bound Keychain item.
    func generateKey() async throws {
        #if targetEnvironment(simulator)
        try await generateLegacyKey()
        #else
        let seKey = try getOrCreateSEPrivateKey()
        let aesKeyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrapped = try wrapAESKey(aesKeyData, with: seKey)
        try await keychainService.save(wrapped, forKey: seWrappedKeyID)
        #endif
    }

    // MARK: - Key retrieval

    private func getOrCreateKey() async throws -> SymmetricKey {
        #if targetEnvironment(simulator)
        return try await getOrCreateLegacyKey()
        #else
        return try await getOrCreateSEBoundKey()
        #endif
    }

    // MARK: - SE path (device only)

    private func getOrCreateSEBoundKey() async throws -> SymmetricKey {
        let seKey = try getOrCreateSEPrivateKey()

        // 1. SE-wrapped key already stored — unwrap and return.
        if let wrapped = try await keychainService.load(forKey: seWrappedKeyID) {
            return try unwrapAESKey(wrapped, with: seKey)
        }

        // 2. Migrate a legacy raw key if one exists (first upgrade after SEC-03).
        let legacyData: Data?
        do {
            legacyData = try await keychainService.load(
                forKey: legacyKeyID,
                access: .biometricBound
            )
        } catch {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to migrate the legacy encryption key: \(error.localizedDescription)")
            )
        }

        if let legacyData {
            let wrapped = try wrapAESKey(legacyData, with: seKey)
            try await keychainService.save(wrapped, forKey: seWrappedKeyID)
            try await keychainService.delete(forKey: legacyKeyID)
            return SymmetricKey(data: legacyData)
        }

        // 3. Fresh install — generate, wrap, persist, return.
        let aesKeyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrapped = try wrapAESKey(aesKeyData, with: seKey)
        try await keychainService.save(wrapped, forKey: seWrappedKeyID)
        return SymmetricKey(data: aesKeyData)
    }

    // MARK: - SE private key lifecycle

    private func getOrCreateSEPrivateKey() throws -> SecKey {
        if let existing = loadSEPrivateKey() { return existing }
        return try createSEPrivateKey()
    }

    private func loadSEPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrApplicationTag as String: seKeyTag,
            kSecReturnRef as String: true,
            kSecUseOperationPrompt as String: String(
                localized: "Authenticate to access your encrypted Vittora data."
            ),
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let ref = item,
              CFGetTypeID(ref) == SecKeyGetTypeID() else { return nil }
        // SecKey is a CoreFoundation type; after checking CFTypeID, this bridge is safe.
        return unsafeBitCast(ref, to: SecKey.self)
    }

    private func createSEPrivateKey() throws -> SecKey {
        guard let acl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to create Secure Enclave access control.")
            )
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: seKeyTag,
                kSecAttrAccessControl as String: acl,
            ],
        ]

        var cfError: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &cfError) else {
            let msg = cfError.map { String(describing: $0.takeRetainedValue()) }
                ?? String(localized: "Unknown SE error")
            throw VittoraError.encryptionFailed(msg)
        }
        return key
    }

    // MARK: - ECIES key wrap / unwrap

    private func wrapAESKey(_ aesKeyData: Data, with sePrivateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(sePrivateKey) else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to derive Secure Enclave public key.")
            )
        }
        var cfError: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(
            publicKey, eciesAlgorithm, aesKeyData as CFData, &cfError
        ) as Data? else {
            let msg = cfError.map { String(describing: $0.takeRetainedValue()) }
                ?? String(localized: "Unknown SE error")
            throw VittoraError.encryptionFailed(msg)
        }
        return wrapped
    }

    private func unwrapAESKey(_ wrappedData: Data, with sePrivateKey: SecKey) throws -> SymmetricKey {
        var cfError: Unmanaged<CFError>?
        guard let aesKeyData = SecKeyCreateDecryptedData(
            sePrivateKey, eciesAlgorithm, wrappedData as CFData, &cfError
        ) as Data? else {
            let msg = cfError.map { String(describing: $0.takeRetainedValue()) }
                ?? String(localized: "Unknown SE error")
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to unwrap Secure Enclave key: \(msg)")
            )
        }
        return SymmetricKey(data: aesKeyData)
    }

    // MARK: - Legacy / simulator path

    private func generateLegacyKey() async throws {
        let newKey = SymmetricKey(size: .bits256)
        try await keychainService.save(
            newKey.withUnsafeBytes { Data($0) },
            forKey: legacyKeyID,
            access: .biometricBound
        )
    }

    private func getOrCreateLegacyKey() async throws -> SymmetricKey {
        if let existing = try await keychainService.load(
            forKey: legacyKeyID,
            access: .biometricBound
        ) {
            return SymmetricKey(data: existing)
        }
        try await generateLegacyKey()
        guard let keyData = try await keychainService.load(
            forKey: legacyKeyID,
            access: .biometricBound
        ) else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to retrieve generated key")
            )
        }
        return SymmetricKey(data: keyData)
    }
}
