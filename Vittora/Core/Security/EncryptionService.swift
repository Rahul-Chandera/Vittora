import Foundation
import CryptoKit
import Security
import VittoraCore

/// AES-256-GCM encryption service.
///
/// On real devices the AES key is wrapped with an EC P-256 key that lives in
/// the Secure Enclave, so the raw AES bytes never leave hardware. On the
/// Simulator (no SE) the key falls back to a biometric-bound Keychain item.
@MainActor
final class EncryptionService: EncryptionServiceProtocol, Sendable {
    private let keychainService: any KeychainServiceProtocol

    /// In-memory cache after first successful key resolution.
    private var cachedKey: SymmetricKey?
    /// Coalesces concurrent first-time key creation (SECURITY-6 / B6).
    private var keyCreationTask: Task<SymmetricKey, Error>?

    /// Keychain item that stores the ECIES-wrapped AES key (device path).
    private let seWrappedKeyID = "com.vittora.encryption.key.se_wrapped"
    /// Keychain item for the raw AES key (simulator path / legacy).
    private let legacyKeyID = "com.vittora.encryption.key"
    /// SE key tag used as the `kSecAttrApplicationTag` search criterion.
    private let seKeyTag = Data("com.vittora.se.key".utf8)
    /// ECIES variant supported by the Secure Enclave.
    private let eciesAlgorithm =
        SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM

    #if DEBUG
    /// Forces the simulator/legacy key path so unit tests avoid Secure Enclave biometry.
    private let useLegacyKeyPathForTesting: Bool
    #endif

    init(keychainService: any KeychainServiceProtocol) {
        self.keychainService = keychainService
        #if DEBUG
        self.useLegacyKeyPathForTesting = false
        #endif
    }

    #if DEBUG
    init(
        keychainService: any KeychainServiceProtocol,
        useLegacyKeyPathForTesting: Bool
    ) {
        self.keychainService = keychainService
        self.useLegacyKeyPathForTesting = useLegacyKeyPathForTesting
    }
    #endif

    // MARK: - Public interface

    func encrypt(_ data: Data) async throws -> Data {
        let key = try await getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw SecurityErrorMapper.encryptionFailed(.encrypt)
        }
        return combined
    }

    func decrypt(_ encryptedData: Data) async throws -> Data {
        let key = try await getOrCreateKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityErrorMapper.encryptionFailed(.decrypt, underlying: error)
        }
    }

    /// Creates a new AES key (replacing any existing one) and persists it.
    /// On device the key is wrapped by a Secure Enclave EC key; on the
    /// Simulator it is stored as a biometric-bound Keychain item.
    func generateKey() async throws {
        if let inFlight = keyCreationTask {
            _ = try? await inFlight.value
        }
        cachedKey = nil
        keyCreationTask = nil

        if usesLegacyKeyPath {
            try await generateLegacyKey()
        } else {
            let seKey = try getOrCreateSEPrivateKey()
            let aesKeyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            let wrapped = try wrapAESKey(aesKeyData, with: seKey)
            try await keychainService.save(wrapped, forKey: seWrappedKeyID)
            cachedKey = SymmetricKey(data: aesKeyData)
        }
    }

    // MARK: - Key retrieval

    private func getOrCreateKey() async throws -> SymmetricKey {
        if let cachedKey { return cachedKey }

        if let inFlight = keyCreationTask {
            return try await inFlight.value
        }

        let task = Task { @MainActor in
            defer { self.keyCreationTask = nil }

            if let cached = self.cachedKey { return cached }

            let key: SymmetricKey
            if self.usesLegacyKeyPath {
                key = try await self.getOrCreateLegacyKey()
            } else {
                key = try await self.getOrCreateSEBoundKey()
            }
            self.cachedKey = key
            return key
        }
        keyCreationTask = task
        return try await task.value
    }

    private var usesLegacyKeyPath: Bool {
        #if DEBUG
        if useLegacyKeyPathForTesting { return true }
        #endif
        #if targetEnvironment(simulator)
        return true
        #else
        return false
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
            throw SecurityErrorMapper.encryptionFailed(.legacyKeyMigration, underlying: error)
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
            throw SecurityErrorMapper.encryptionFailed(.secureEnclaveSetup)
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
            throw SecurityErrorMapper.encryptionFailed(
                .secureEnclaveSetup,
                cfError: cfError?.takeRetainedValue()
            )
        }
        return key
    }

    // MARK: - ECIES key wrap / unwrap

    private func wrapAESKey(_ aesKeyData: Data, with sePrivateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(sePrivateKey) else {
            throw SecurityErrorMapper.encryptionFailed(.secureEnclavePublicKey)
        }
        var cfError: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(
            publicKey, eciesAlgorithm, aesKeyData as CFData, &cfError
        ) as Data? else {
            throw SecurityErrorMapper.encryptionFailed(
                .secureEnclaveWrap,
                cfError: cfError?.takeRetainedValue()
            )
        }
        return wrapped
    }

    private func unwrapAESKey(_ wrappedData: Data, with sePrivateKey: SecKey) throws -> SymmetricKey {
        var cfError: Unmanaged<CFError>?
        guard let aesKeyData = SecKeyCreateDecryptedData(
            sePrivateKey, eciesAlgorithm, wrappedData as CFData, &cfError
        ) as Data? else {
            throw SecurityErrorMapper.encryptionFailed(
                .secureEnclaveUnwrap,
                cfError: cfError?.takeRetainedValue()
            )
        }
        return SymmetricKey(data: aesKeyData)
    }

    // MARK: - Legacy / simulator path

    private func generateLegacyKey() async throws {
        if let existing = try await keychainService.load(
            forKey: legacyKeyID,
            access: .biometricBound
        ) {
            cachedKey = SymmetricKey(data: existing)
            return
        }
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
            throw SecurityErrorMapper.encryptionFailed(.keyRetrieval)
        }
        return SymmetricKey(data: keyData)
    }
}
