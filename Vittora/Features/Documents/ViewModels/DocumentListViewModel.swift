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
    let transactionID: UUID

    init(
        transactionID: UUID,
        fetchUseCase: FetchDocumentsUseCase,
        attachUseCase: AttachDocumentUseCase,
        deleteUseCase: DeleteDocumentUseCase
    ) {
        self.transactionID = transactionID
        self.fetchUseCase = fetchUseCase
        self.attachUseCase = attachUseCase
        self.deleteUseCase = deleteUseCase
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

    func fileURL(for entity: DocumentEntity) -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(entity.fileName)
    }
}
