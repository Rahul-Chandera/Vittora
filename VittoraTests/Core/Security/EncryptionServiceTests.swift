import Testing
@testable import Vittora

@Suite("EncryptionService Tests")
@MainActor
struct EncryptionServiceTests {
    private let mockKeychain = MockKeychainService()
    private var encryptionService: EncryptionService?

    init() {
        encryptionService = EncryptionService(keychainService: mockKeychain)
    }

    @Test("Encrypt and decrypt round-trip")
    async throws {
        let service = encryptionService!
        let originalData = "Hello, World!".data(using: .utf8)!

        let encrypted = try await service.encrypt(originalData)
        #expect(encrypted.count > 0)
        #expect(encrypted != originalData)

        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == originalData)
    }

    @Test("Encrypt different data sizes")
    async throws {
        let service = encryptionService!

        let smallData = "Hi".data(using: .utf8)!
        let smallEncrypted = try await service.encrypt(smallData)
        let smallDecrypted = try await service.decrypt(smallEncrypted)
        #expect(smallDecrypted == smallData)

        let mediumData = "Lorem ipsum dolor sit amet, consectetur adipiscing elit.".data(using: .utf8)!
        let mediumEncrypted = try await service.encrypt(mediumData)
        let mediumDecrypted = try await service.decrypt(mediumEncrypted)
        #expect(mediumDecrypted == mediumData)

        let largeData = Data(repeating: 0xFF, count: 10000)
        let largeEncrypted = try await service.encrypt(largeData)
        let largeDecrypted = try await service.decrypt(largeEncrypted)
        #expect(largeDecrypted == largeData)
    }

    @Test("Encrypt produces different output for same input")
    async throws {
        let service = encryptionService!
        let data = "Same Data".data(using: .utf8)!

        let encrypted1 = try await service.encrypt(data)
        let encrypted2 = try await service.encrypt(data)

        #expect(encrypted1 != encrypted2)
    }

    @Test("Decrypt invalid data throws error")
    async throws {
        let service = encryptionService!
        let invalidData = "invalid-encrypted-data".data(using: .utf8)!

        await #expect(throws: VittoraError.self) {
            try await service.decrypt(invalidData)
        }
    }

    @Test("Key is generated and stored")
    async throws {
        let service = encryptionService!
        mockKeychain.reset()

        try await service.generateKey()
        let keyExists = try await mockKeychain.exists(forKey: "com.vittora.encryption.key")
        #expect(keyExists)
    }

    @Test("Empty data encryption round-trip")
    async throws {
        let service = encryptionService!
        let emptyData = Data()

        let encrypted = try await service.encrypt(emptyData)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == emptyData)
    }

    @Test("Multiple sequential encryptions use same key")
    async throws {
        let service = encryptionService!
        let data1 = "First".data(using: .utf8)!
        let data2 = "Second".data(using: .utf8)!

        let encrypted1 = try await service.encrypt(data1)
        let encrypted2 = try await service.encrypt(data2)

        let decrypted1 = try await service.decrypt(encrypted1)
        let decrypted2 = try await service.decrypt(encrypted2)

        #expect(decrypted1 == data1)
        #expect(decrypted2 == data2)
    }
}
