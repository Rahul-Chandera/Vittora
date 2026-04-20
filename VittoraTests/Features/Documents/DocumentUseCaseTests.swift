import Foundation
import Testing
@testable import Vittora

@Suite("Document Use Case Tests")
@MainActor
struct DocumentUseCaseTests {

    // MARK: - AttachDocumentUseCase

    @Suite("AttachDocumentUseCase")
    @MainActor
    struct AttachDocumentUseCaseTests {

        @Test("execute stores document bytes before creating repository metadata")
        func attachStoresDocumentBytes() async throws {
            let repo = MockDocumentRepository()
            let storage = MockDocumentStorageService()
            let useCase = AttachDocumentUseCase(
                documentRepository: repo,
                documentStorageService: storage
            )
            let txID = UUID()
            let imageData = Data("receipt-image".utf8)

            let entity = try await useCase.execute(
                imageData: imageData,
                mimeType: "image/jpeg",
                transactionID: txID
            )

            let storedEntity = try #require(repo.documents.first)
            #expect(storedEntity.id == entity.id)
            #expect(storage.savedDocuments[entity.id] == imageData)
            #expect(storedEntity.transactionID == txID)
        }
    }

    // MARK: - FetchDocumentsUseCase

    @Suite("FetchDocumentsUseCase")
    @MainActor
    struct FetchDocumentsUseCaseTests {

        @Test("execute(for:) returns only documents for that transaction")
        func fetchForTransaction() async throws {
            let repo = MockDocumentRepository()
            let txID = UUID()
            let other = UUID()

            let doc1 = DocumentEntity(fileName: "a.jpg", transactionID: txID)
            let doc2 = DocumentEntity(fileName: "b.jpg", transactionID: txID)
            let doc3 = DocumentEntity(fileName: "c.pdf", transactionID: other)
            repo.seed(doc1)
            repo.seed(doc2)
            repo.seed(doc3)

            let useCase = FetchDocumentsUseCase(documentRepository: repo)
            let result = try await useCase.execute(for: txID)

            #expect(result.count == 2)
            #expect(result.allSatisfy { $0.transactionID == txID })
        }

        @Test("execute(for:) returns empty when no matching transaction")
        func fetchForTransactionEmpty() async throws {
            let repo = MockDocumentRepository()
            let useCase = FetchDocumentsUseCase(documentRepository: repo)
            let result = try await useCase.execute(for: UUID())
            #expect(result.isEmpty)
        }

        @Test("executeAll() returns all documents regardless of transaction")
        func executeAll() async throws {
            let repo = MockDocumentRepository()
            repo.seed(DocumentEntity(fileName: "x.jpg", transactionID: UUID()))
            repo.seed(DocumentEntity(fileName: "y.pdf", transactionID: nil))

            let useCase = FetchDocumentsUseCase(documentRepository: repo)
            let result = try await useCase.executeAll()

            #expect(result.count == 2)
        }
    }

    // MARK: - DeleteDocumentUseCase

    @Suite("DeleteDocumentUseCase")
    @MainActor
    struct DeleteDocumentUseCaseTests {

        @Test("deletes document from repository")
        func deletesFromRepository() async throws {
            let repo = MockDocumentRepository()
            let storage = MockDocumentStorageService()
            let doc = DocumentEntity(fileName: "receipt.jpg", transactionID: nil)
            repo.seed(doc)
            try await storage.saveDocument(Data("ciphertext".utf8), for: doc)

            let useCase = DeleteDocumentUseCase(
                documentRepository: repo,
                documentStorageService: storage
            )
            try await useCase.execute(id: doc.id)

            let remaining = try await repo.fetchAll()
            #expect(remaining.isEmpty)
            #expect(storage.savedDocuments[doc.id] == nil)
            #expect(storage.deletedDocuments.contains(doc.id))
        }

        @Test("is a no-op when document does not exist")
        func noOpForMissingDocument() async throws {
            let repo = MockDocumentRepository()
            let storage = MockDocumentStorageService()
            let useCase = DeleteDocumentUseCase(
                documentRepository: repo,
                documentStorageService: storage
            )
            // Should not throw even for an unknown ID
            try await useCase.execute(id: UUID())
        }

        @Test("does not affect other documents")
        func doesNotAffectOtherDocuments() async throws {
            let repo = MockDocumentRepository()
            let storage = MockDocumentStorageService()
            let keep = DocumentEntity(fileName: "keep.pdf", transactionID: nil)
            let remove = DocumentEntity(fileName: "remove.jpg", transactionID: nil)
            repo.seed(keep)
            repo.seed(remove)
            try await storage.saveDocument(Data("keep".utf8), for: keep)
            try await storage.saveDocument(Data("remove".utf8), for: remove)

            let useCase = DeleteDocumentUseCase(
                documentRepository: repo,
                documentStorageService: storage
            )
            try await useCase.execute(id: remove.id)

            let remaining = try await repo.fetchAll()
            #expect(remaining.count == 1)
            #expect(remaining.first?.id == keep.id)
            #expect(storage.savedDocuments[keep.id] != nil)
            #expect(storage.savedDocuments[remove.id] == nil)
        }
    }
}
