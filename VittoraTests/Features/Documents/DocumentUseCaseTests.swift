import Foundation
import Testing
@testable import Vittora

@Suite("Document Use Case Tests")
@MainActor
struct DocumentUseCaseTests {

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
            let doc = DocumentEntity(fileName: "receipt.jpg", transactionID: nil)
            repo.seed(doc)

            let useCase = DeleteDocumentUseCase(documentRepository: repo)
            try await useCase.execute(id: doc.id)

            let remaining = try await repo.fetchAll()
            #expect(remaining.isEmpty)
        }

        @Test("is a no-op when document does not exist")
        func noOpForMissingDocument() async throws {
            let repo = MockDocumentRepository()
            let useCase = DeleteDocumentUseCase(documentRepository: repo)
            // Should not throw even for an unknown ID
            try await useCase.execute(id: UUID())
        }

        @Test("does not affect other documents")
        func doesNotAffectOtherDocuments() async throws {
            let repo = MockDocumentRepository()
            let keep = DocumentEntity(fileName: "keep.pdf", transactionID: nil)
            let remove = DocumentEntity(fileName: "remove.jpg", transactionID: nil)
            repo.seed(keep)
            repo.seed(remove)

            let useCase = DeleteDocumentUseCase(documentRepository: repo)
            try await useCase.execute(id: remove.id)

            let remaining = try await repo.fetchAll()
            #expect(remaining.count == 1)
            #expect(remaining.first?.id == keep.id)
        }
    }
}
