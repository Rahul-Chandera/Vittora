import Foundation

struct DeleteDocumentUseCase: Sendable {
    let documentRepository: any DocumentRepository

    func execute(id: UUID) async throws {
        guard let entity = try await documentRepository.fetchByID(id) else { return }
        try deleteFile(fileName: entity.fileName)
        try await documentRepository.delete(id)
    }

    private func deleteFile(fileName: String) throws {
        guard let documentsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
