import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataDocumentRepository Tests")
@MainActor
struct SwiftDataDocumentRepositoryTests {

    private func makeRepo(
        storage: MockDocumentStorageService? = nil
    ) throws -> EncryptedDocumentRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        let resolvedStorage = storage ?? MockDocumentStorageService()
        return EncryptedDocumentRepository(
            modelContainer: container,
            documentStorageService: resolvedStorage
        )
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        // Do not set thumbnailData to avoid filesystem side effects in test
        let entity = DocumentEntity(
            id: UUID(),
            fileName: "receipt.jpg",
            mimeType: "image/jpeg",
            thumbnailData: nil,
            transactionID: nil,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.fileName == "receipt.jpg")
        #expect(all.first?.mimeType == "image/jpeg")
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = DocumentEntity(
            id: id,
            fileName: "invoice.pdf",
            mimeType: "application/pdf",
            thumbnailData: nil,
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.fileName == "invoice.pdf")
        #expect(found?.mimeType == "application/pdf")
    }

    @Test("fetchByID returns nil for unknown ID")
    func testFetchByIDReturnsNil() async throws {
        let repo = try makeRepo()

        let result = try await repo.fetchByID(UUID())

        #expect(result == nil)
    }

    @Test("update modifies persisted fields")
    func testUpdate() async throws {
        let repo = try makeRepo()
        let id = UUID()
        var entity = DocumentEntity(
            id: id,
            fileName: "old_name.jpg",
            mimeType: "image/jpeg",
            thumbnailData: nil,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.fileName = "new_name.jpg"
        entity.mimeType = "image/png"
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.fileName == "new_name.jpg")
        #expect(updated?.mimeType == "image/png")
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = DocumentEntity(
            id: UUID(),
            fileName: "ghost.jpg",
            thumbnailData: nil,
            createdAt: Date(timeIntervalSince1970: 4_000_000),
            updatedAt: Date(timeIntervalSince1970: 4_000_000)
        )

        do {
            try await repo.update(entity)
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    @Test("delete removes entity")
    func testDelete() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = DocumentEntity(
            id: id,
            fileName: "to_delete.jpg",
            thumbnailData: nil,
            createdAt: Date(timeIntervalSince1970: 5_000_000),
            updatedAt: Date(timeIntervalSince1970: 5_000_000)
        )
        try await repo.create(entity)

        try await repo.delete(id)
        let all = try await repo.fetchAll()

        #expect(all.isEmpty)
    }

    @Test("delete throws notFound for missing ID")
    func testDeleteNotFound() async throws {
        let repo = try makeRepo()

        do {
            try await repo.delete(UUID())
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    // MARK: - fetchForTransaction

    @Test("fetchForTransaction returns only documents linked to the given transaction")
    func testFetchForTransaction() async throws {
        let repo = try makeRepo()
        let txID = UUID()
        let otherTxID = UUID()

        try await repo.create(DocumentEntity(
            id: UUID(), fileName: "receipt1.jpg", thumbnailData: nil,
            transactionID: txID,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(DocumentEntity(
            id: UUID(), fileName: "receipt2.jpg", thumbnailData: nil,
            transactionID: txID,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))
        try await repo.create(DocumentEntity(
            id: UUID(), fileName: "other_receipt.jpg", thumbnailData: nil,
            transactionID: otherTxID,
            createdAt: Date(timeIntervalSince1970: 6_200_000),
            updatedAt: Date(timeIntervalSince1970: 6_200_000)
        ))

        let docs = try await repo.fetchForTransaction(txID)

        #expect(docs.count == 2)
        #expect(docs.allSatisfy { $0.transactionID == txID })
    }

    @Test("fetchForTransaction returns empty when no documents linked to transaction")
    func testFetchForTransactionEmpty() async throws {
        let repo = try makeRepo()

        let docs = try await repo.fetchForTransaction(UUID())

        #expect(docs.isEmpty)
    }

    @Test("fetchForTransaction with nil transactionID does not match documents with a transaction")
    func testFetchForTransactionDoesNotReturnUnlinked() async throws {
        let repo = try makeRepo()
        let txID = UUID()

        try await repo.create(DocumentEntity(
            id: UUID(), fileName: "linked.jpg", thumbnailData: nil,
            transactionID: txID,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let results = try await repo.fetchForTransaction(UUID())
        #expect(results.isEmpty)
    }

    @Test("fetchByID hydrates thumbnail data from secure storage")
    func testFetchByIDHydratesThumbnailData() async throws {
        let storage = MockDocumentStorageService()
        let repo = try makeRepo(storage: storage)
        let id = UUID()
        let thumbnailData = Data("thumb".utf8)

        try await repo.create(
            DocumentEntity(
                id: id,
                fileName: "receipt.jpg",
                mimeType: "image/jpeg",
                thumbnailData: thumbnailData,
                createdAt: Date(timeIntervalSince1970: 8_000_000),
                updatedAt: Date(timeIntervalSince1970: 8_000_000)
            )
        )

        let found = try await repo.fetchByID(id)

        #expect(found?.thumbnailData == thumbnailData)
        #expect(storage.savedThumbnails[id] == thumbnailData)
    }

    @Test("create removes metadata when thumbnail persistence fails")
    func testCreateRollsBackMetadataOnThumbnailSaveFailure() async throws {
        let storage = MockDocumentStorageService()
        storage.shouldThrowError = true
        let repo = try makeRepo(storage: storage)
        let entity = DocumentEntity(
            id: UUID(),
            fileName: "receipt.jpg",
            mimeType: "image/jpeg",
            thumbnailData: Data("thumb".utf8),
            createdAt: Date(timeIntervalSince1970: 9_000_000),
            updatedAt: Date(timeIntervalSince1970: 9_000_000)
        )

        do {
            try await repo.create(entity)
            Issue.record("Expected thumbnail persistence to throw")
        } catch {
            let remaining = try await repo.fetchAll()
            #expect(remaining.isEmpty)
        }
    }
}
