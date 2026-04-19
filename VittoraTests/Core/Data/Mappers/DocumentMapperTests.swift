import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("DocumentMapper Tests")
struct DocumentMapperTests {

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
}
