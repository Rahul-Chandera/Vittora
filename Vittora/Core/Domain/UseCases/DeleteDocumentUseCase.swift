import Foundation

struct DeleteDocumentUseCase: Sendable {
    let documentRepository: any DocumentRepository
    let documentStorageService: any DocumentStorageServiceProtocol

    func execute(id: UUID) async throws {
        guard let entity = try await documentRepository.fetchByID(id) else { return }
        try await documentStorageService.deleteDocument(for: entity)
        try await documentRepository.delete(id)
    }
}
