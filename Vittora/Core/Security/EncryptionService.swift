import Foundation
import CryptoKit

protocol EncryptionServiceProtocol: Sendable {
    func encrypt(_ data: Data) async throws -> Data
    func decrypt(_ encryptedData: Data) async throws -> Data
    func generateKey() async throws
}

@MainActor
final class EncryptionService: EncryptionServiceProtocol, Sendable {
    private let keychainService: any KeychainServiceProtocol
    private let keyIdentifier = "com.vittora.encryption.key"

    init(keychainService: any KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

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

        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData) else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to parse encrypted data")
            )
        }

        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to decrypt data: \(error.localizedDescription)")
            )
        }
    }

    func generateKey() async throws {
        let newKey = SymmetricKey(size: .bits256)
        try await keychainService.save(newKey.withUnsafeBytes { Data($0) }, forKey: keyIdentifier)
    }

    private func getOrCreateKey() async throws -> SymmetricKey {
        if let existingKeyData = try await keychainService.load(forKey: keyIdentifier) {
            return SymmetricKey(data: existingKeyData)
        }

        try await generateKey()
        guard let keyData = try await keychainService.load(forKey: keyIdentifier) else {
            throw VittoraError.encryptionFailed(
                String(localized: "Failed to retrieve generated key")
            )
        }

        return SymmetricKey(data: keyData)
    }
}
