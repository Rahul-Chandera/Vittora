import Foundation
import Testing
@testable import Vittora

@Suite("EncryptionService Tests", .serialized)
@MainActor
struct EncryptionServiceTests {

    private func makeService() -> (EncryptionService, MockKeychainService) {
        let keychain = MockKeychainService()
        #if DEBUG
        let service = EncryptionService(keychainService: keychain, useLegacyKeyPathForTesting: true)
        #else
        let service = EncryptionService(keychainService: keychain)
        #endif
        return (service, keychain)
    }

    @Test("Encrypt and decrypt round-trip")
    func encryptDecryptRoundTrip() async throws {
        let (service, _) = makeService()
        let originalData = "Hello, World!".data(using: .utf8)!
        let encrypted = try await service.encrypt(originalData)
        #expect(encrypted.count > 0)
        #expect(encrypted != originalData)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == originalData)
    }

    @Test("Encrypt different data sizes")
    func encryptDifferentSizes() async throws {
        let (service, _) = makeService()
        let smallData = "Hi".data(using: .utf8)!
        let smallEncrypted = try await service.encrypt(smallData)
        let smallDecrypted = try await service.decrypt(smallEncrypted)
        #expect(smallDecrypted == smallData)

        let mediumData = "Lorem ipsum dolor sit amet.".data(using: .utf8)!
        let mediumEncrypted = try await service.encrypt(mediumData)
        let mediumDecrypted = try await service.decrypt(mediumEncrypted)
        #expect(mediumDecrypted == mediumData)

        let largeData = Data(repeating: 0xFF, count: 10000)
        let largeEncrypted = try await service.encrypt(largeData)
        let largeDecrypted = try await service.decrypt(largeEncrypted)
        #expect(largeDecrypted == largeData)
    }

    @Test("Encrypt produces different output for same input")
    func encryptNonDeterministic() async throws {
        let (service, _) = makeService()
        let data = "Same Data".data(using: .utf8)!
        let encrypted1 = try await service.encrypt(data)
        let encrypted2 = try await service.encrypt(data)
        #expect(encrypted1 != encrypted2)
    }

    @Test("Decrypt invalid data throws error")
    func decryptInvalidDataThrows() async throws {
        let (service, _) = makeService()
        let invalidData = "invalid-encrypted-data".data(using: .utf8)!
        await #expect(throws: VittoraError.self) {
            try await service.decrypt(invalidData)
        }
    }

    @Test("Key is generated and stored")
    func keyGeneratedAndStored() async throws {
        let (service, keychain) = makeService()
        try await service.generateKey()
        let keyExists = try await keychain.exists(forKey: "com.vittora.encryption.key")
        #expect(keyExists)
    }

    @Test("Empty data encryption round-trip")
    func emptyDataRoundTrip() async throws {
        let (service, _) = makeService()
        let emptyData = Data()
        let encrypted = try await service.encrypt(emptyData)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == emptyData)
    }

    @Test("Multiple sequential encryptions use same key")
    func multipleEncryptionsSameKey() async throws {
        let (service, _) = makeService()
        let data1 = "First".data(using: .utf8)!
        let data2 = "Second".data(using: .utf8)!
        let encrypted1 = try await service.encrypt(data1)
        let encrypted2 = try await service.encrypt(data2)
        let decrypted1 = try await service.decrypt(encrypted1)
        let decrypted2 = try await service.decrypt(encrypted2)
        #expect(decrypted1 == data1)
        #expect(decrypted2 == data2)
    }

    @Test("parallel encrypt on empty keychain creates one key")
    func parallelEncryptCreatesSingleKey() async throws {
        let (service, keychain) = makeService()
        keychain.loadDelayNanoseconds = 50_000_000
        let payload = "concurrent-key-create".data(using: .utf8)!

        async let first = service.encrypt(payload)
        async let second = service.encrypt(payload)
        async let third = service.encrypt(payload)
        let encrypted = try await (first, second, third)

        let keySaves = keychain.saveCount(forKey: "com.vittora.encryption.key")
            + keychain.saveCount(forKey: "com.vittora.encryption.key.se_wrapped")
        #expect(keySaves <= 1)

        #expect(try await service.decrypt(encrypted.0) == payload)
        #expect(try await service.decrypt(encrypted.1) == payload)
        #expect(try await service.decrypt(encrypted.2) == payload)
    }
}
