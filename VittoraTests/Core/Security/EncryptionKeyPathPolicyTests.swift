import Foundation
import Testing
import VittoraCore

@Suite("EncryptionKeyPathPolicy Tests")
struct EncryptionKeyPathPolicyTests {

    @Test("Device uses Secure Enclave wrapped path")
    func deviceUsesSecureEnclavePath() {
        #expect(
            EncryptionKeyPathPolicy.storagePath(
                isSimulator: false,
                forceLegacyForTesting: false
            ) == .secureEnclaveWrapped
        )
    }

    @Test("Simulator uses legacy biometric keychain path")
    func simulatorUsesLegacyPath() {
        #expect(
            EncryptionKeyPathPolicy.storagePath(
                isSimulator: true,
                forceLegacyForTesting: false
            ) == .legacyBiometricKeychain
        )
    }

    @Test("DEBUG test hook forces legacy path on device")
    func forceLegacyForTesting() {
        #expect(
            EncryptionKeyPathPolicy.storagePath(
                isSimulator: false,
                forceLegacyForTesting: true
            ) == .legacyBiometricKeychain
        )
    }

    @Test("SE resolution prefers existing wrapped key")
    func unwrapWhenWrappedKeyExists() {
        let legacy = Data(repeating: 0xAB, count: 32)
        #expect(
            EncryptionKeyPathPolicy.secureEnclaveKeyResolution(
                hasWrappedKey: true,
                legacyKeyData: legacy
            ) == .unwrapExisting
        )
    }

    @Test("SE resolution migrates legacy raw key when no wrapped key")
    func migrateLegacyKey() {
        let legacy = Data(repeating: 0xCD, count: 32)
        #expect(
            EncryptionKeyPathPolicy.secureEnclaveKeyResolution(
                hasWrappedKey: false,
                legacyKeyData: legacy
            ) == .migrateFromLegacy(legacy)
        )
    }

    @Test("SE resolution generates fresh key on clean install")
    func generateFreshKey() {
        #expect(
            EncryptionKeyPathPolicy.secureEnclaveKeyResolution(
                hasWrappedKey: false,
                legacyKeyData: nil
            ) == .generateFresh
        )
    }
}
