import Foundation
import Observation

@Observable
@MainActor
final class DocumentListViewModel {
    var documents: [DocumentEntity] = []
    var isLoading = false
    var error: String?

    private let fetchUseCase: FetchDocumentsUseCase
    private let attachUseCase: AttachDocumentUseCase
    private let deleteUseCase: DeleteDocumentUseCase
    private let documentStorageService: any DocumentStorageServiceProtocol
    let transactionID: UUID

    init(
        transactionID: UUID,
        fetchUseCase: FetchDocumentsUseCase,
        attachUseCase: AttachDocumentUseCase,
        deleteUseCase: DeleteDocumentUseCase,
        documentStorageService: any DocumentStorageServiceProtocol
    ) {
        self.transactionID = transactionID
        self.fetchUseCase = fetchUseCase
        self.attachUseCase = attachUseCase
        self.deleteUseCase = deleteUseCase
        self.documentStorageService = documentStorageService
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            documents = try await fetchUseCase.execute(for: transactionID)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func attach(imageData: Data, mimeType: String) async {
        error = nil
        do {
            let entity = try await attachUseCase.execute(
                imageData: imageData,
                mimeType: mimeType,
                transactionID: transactionID
            )
            documents.append(entity)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(id: UUID) async {
        error = nil
        do {
            try await deleteUseCase.execute(id: id)
            documents.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func previewItem(for entity: DocumentEntity) async throws -> DocumentPreviewItem {
        let data = try await documentStorageService.loadDocument(for: entity)
        return DocumentPreviewItem(
            id: entity.id,
            fileName: entity.fileName,
            mimeType: entity.mimeType,
            data: data
        )
    }
}
