import Foundation
import Testing
@testable import Vittora

@Suite("KeychainService Tests")
@MainActor
struct KeychainServiceTests {
    private let keychainService = MockKeychainService()

    @Test("Save and load data")
    func saveAndLoadData() async throws {
        let testKey = "test_key_1"
        let testData = "Hello, Keychain!".data(using: .utf8)!
        try await keychainService.save(testData, forKey: testKey)
        let retrieved = try await keychainService.load(forKey: testKey)
        #expect(retrieved == testData)
    }

    @Test("Load non-existent key returns nil")
    func loadNonExistentReturnsNil() async throws {
        let retrieved = try await keychainService.load(forKey: "non_existent_key")
        #expect(retrieved == nil)
    }

    @Test("Delete removes data")
    func deleteRemovesData() async throws {
        let testKey = "test_delete_key"
        let testData = "To be deleted".data(using: .utf8)!
        try await keychainService.save(testData, forKey: testKey)
        #expect(try await keychainService.load(forKey: testKey) != nil)
        try await keychainService.delete(forKey: testKey)
        #expect(try await keychainService.load(forKey: testKey) == nil)
    }

    @Test("Delete non-existent key succeeds")
    func deleteNonExistentSucceeds() async throws {
        try await keychainService.delete(forKey: "non_existent")
    }

    @Test("Exists returns true for stored data")
    func existsReturnsTrueForStored() async throws {
        let testKey = "test_exists_key"
        let testData = "Exists test".data(using: .utf8)!
        try await keychainService.save(testData, forKey: testKey)
        let exists = try await keychainService.exists(forKey: testKey)
        #expect(exists == true)
    }

    @Test("Exists returns false for non-existent data")
    func existsReturnsFalseForMissing() async throws {
        let exists = try await keychainService.exists(forKey: "non_existent")
        #expect(exists == false)
    }

    @Test("Save overwrites existing data")
    func saveOverwritesExisting() async throws {
        let testKey = "test_overwrite_key"
        let data1 = "First data".data(using: .utf8)!
        let data2 = "Second data".data(using: .utf8)!
        try await keychainService.save(data1, forKey: testKey)
        #expect(try await keychainService.load(forKey: testKey) == data1)
        try await keychainService.save(data2, forKey: testKey)
        #expect(try await keychainService.load(forKey: testKey) == data2)
    }

    @Test("Save and load binary data")
    func saveAndLoadBinaryData() async throws {
        let testKey = "test_binary_key"
        let binaryData = Data([0x00, 0xFF, 0x12, 0x34, 0xAB, 0xCD])
        try await keychainService.save(binaryData, forKey: testKey)
        let retrieved = try await keychainService.load(forKey: testKey)
        #expect(retrieved == binaryData)
    }

    @Test("Save and load large data")
    func saveAndLoadLargeData() async throws {
        let testKey = "test_large_key"
        let largeData = Data(repeating: 0xFF, count: 100000)
        try await keychainService.save(largeData, forKey: testKey)
        let retrieved = try await keychainService.load(forKey: testKey)
        #expect(retrieved?.count == largeData.count)
        #expect(retrieved == largeData)
    }

    @Test("Multiple keys stored independently")
    func multipleKeysIndependent() async throws {
        let key1 = "key_1"
        let key2 = "key_2"
        let data1 = "Data 1".data(using: .utf8)!
        let data2 = "Data 2".data(using: .utf8)!
        try await keychainService.save(data1, forKey: key1)
        try await keychainService.save(data2, forKey: key2)
        #expect(try await keychainService.load(forKey: key1) == data1)
        #expect(try await keychainService.load(forKey: key2) == data2)
        try await keychainService.delete(forKey: key1)
        #expect(try await keychainService.load(forKey: key1) == nil)
        #expect(try await keychainService.load(forKey: key2) == data2)
    }

    @Test("Error handling when shouldThrowError is set")
    func errorHandlingWhenFlagSet() async throws {
        keychainService.shouldThrowError = true
        await #expect(throws: VittoraError.self) {
            try await keychainService.save("data".data(using: .utf8)!, forKey: "key")
        }
        keychainService.shouldThrowError = false
    }
}
