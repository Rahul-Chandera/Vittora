import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("DocumentMapper Tests")
struct DocumentMapperTests {

    @MainActor
    final class MockEncryptionService: EncryptionServiceProtocol {
        func encrypt(_ data: Data) async throws -> Data {
            Data(data.reversed()) + Data([0xA5])
        }

        func decrypt(_ encryptedData: Data) async throws -> Data {
            guard encryptedData.last == 0xA5 else {
                throw VittoraError.encryptionFailed(String(localized: "Invalid encrypted payload"))
            }

            return Data(encryptedData.dropLast().reversed())
        }

        func generateKey() async throws {}
    }

    @Test("toEntity maps all persisted fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let fileName = "receipt_march.pdf"
        let mimeType = "application/pdf"
        let transactionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDDocument(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            transactionID: transactionID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = DocumentMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.fileName == fileName)
        #expect(entity.mimeType == mimeType)
        #expect(entity.transactionID == transactionID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil transactionID correctly")
    func testToEntityMapsNilTransactionID() {
        let model = SDDocument(fileName: "standalone_doc.jpg")

        let entity = DocumentMapper.toEntity(model)

        #expect(entity.transactionID == nil)
        #expect(entity.mimeType == "image/jpeg")
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDDocument()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let transactionID = UUID()
        let entity = DocumentEntity(
            fileName: "invoice_q2.pdf",
            mimeType: "application/pdf",
            transactionID: transactionID
        )

        DocumentMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.fileName == "invoice_q2.pdf")
        #expect(model.mimeType == "application/pdf")
        #expect(model.transactionID == transactionID)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all persisted fields")
    func testRoundTripMapping() {
        let id = UUID()
        let transactionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDDocument(
            id: id,
            fileName: "bank_statement.pdf",
            mimeType: "application/pdf",
            transactionID: transactionID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = DocumentMapper.toEntity(model)
        DocumentMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.fileName == "bank_statement.pdf")
        #expect(model.mimeType == "application/pdf")
        #expect(model.transactionID == transactionID)
        #expect(model.createdAt == createdAt)
    }

    @Test("updateModel preserves id and createdAt")
    func testUpdateModelPreservesIdAndCreatedAt() {
        let originalID = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_680_000_000)
        let model = SDDocument()
        model.id = originalID
        model.createdAt = originalCreatedAt

        let entity = DocumentEntity(fileName: "updated.jpg")

        DocumentMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("updateModel clears transactionID when entity has nil")
    func testUpdateModelClearsTransactionID() {
        let model = SDDocument()
        model.transactionID = UUID()

        let entity = DocumentEntity(fileName: "detached.png", transactionID: nil)

        DocumentMapper.updateModel(model, from: entity)

        #expect(model.transactionID == nil)
    }

    @Test("Encrypted document storage writes ciphertext at rest and decrypts on load")
    @MainActor
    func encryptedStorageRoundTrip() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = EncryptedDocumentStorageService(
            encryptionService: MockEncryptionService(),
            secureBaseDirectoryURL: tempDirectory
        )
        let entity = DocumentEntity(fileName: "receipt.jpg", mimeType: "image/jpeg")
        let plaintext = Data("private receipt bytes".utf8)

        try await storage.saveDocument(plaintext, for: entity)

        let encryptedURL = tempDirectory
            .appendingPathComponent("\(entity.id.uuidString).document.enc")
        let ciphertext = try Data(contentsOf: encryptedURL)
        let decrypted = try await storage.loadDocument(for: entity)

        #expect(ciphertext != plaintext)
        #expect(decrypted == plaintext)

        try? FileManager.default.removeItem(at: tempDirectory)
    }
}
