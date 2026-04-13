import Foundation

struct FetchDocumentsUseCase: Sendable {
    let documentRepository: any DocumentRepository

    func execute(for transactionID: UUID) async throws -> [DocumentEntity] {
        try await documentRepository.fetchForTransaction(transactionID)
    }

    func executeAll() async throws -> [DocumentEntity] {
        try await documentRepository.fetchAll()
    }
}
