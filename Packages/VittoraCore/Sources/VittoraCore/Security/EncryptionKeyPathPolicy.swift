import Foundation

/// Where the AES-256-GCM data-encryption key is persisted.
public enum EncryptionKeyStoragePath: Sendable, Equatable {
    /// Device path: AES key wrapped with a Secure Enclave EC key (`se_wrapped` keychain item).
    case secureEnclaveWrapped
    /// Simulator / legacy path: raw AES key in a biometric-bound keychain item.
    case legacyBiometricKeychain
}

/// Pure decision for resolving the AES key on the Secure Enclave storage path.
public enum SecureEnclaveKeyResolution: Sendable, Equatable {
    case unwrapExisting
    case migrateFromLegacy(Data)
    case generateFresh
}

/// Testable policy for Secure Enclave vs legacy key storage (TESTING-4 / L5).
///
/// Hardware wrap/unwrap and ECIES round-trips are verified manually on a physical device;
/// see `Docs/Runbooks/RELEASE_CHECKLIST.md` §2.
public enum EncryptionKeyPathPolicy {
    public static func storagePath(
        isSimulator: Bool,
        forceLegacyForTesting: Bool
    ) -> EncryptionKeyStoragePath {
        if forceLegacyForTesting || isSimulator {
            return .legacyBiometricKeychain
        }
        return .secureEnclaveWrapped
    }

    public static func secureEnclaveKeyResolution(
        hasWrappedKey: Bool,
        legacyKeyData: Data?
    ) -> SecureEnclaveKeyResolution {
        if hasWrappedKey { return .unwrapExisting }
        if let legacyKeyData { return .migrateFromLegacy(legacyKeyData) }
        return .generateFresh
    }
}
