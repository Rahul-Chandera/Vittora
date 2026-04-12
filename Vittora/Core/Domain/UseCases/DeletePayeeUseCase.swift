import Foundation

struct DeletePayeeUseCase: Sendable {
    private let repository: any PayeeRepository
    private let transactionRepository: any TransactionRepository

    init(repository: any PayeeRepository, transactionRepository: any TransactionRepository) {
        self.repository = repository
        self.transactionRepository = transactionRepository
    }

    func execute(id: UUID) async throws {
        guard (try await repository.fetchByID(id)) != nil else {
            throw VittoraError.notFound("Payee not found")
        }

        let filter = TransactionFilter(payeeIDs: [id])
        let linked = try await transactionRepository.fetchAll(filter: filter)
        guard linked.isEmpty else {
            throw VittoraError.validationFailed("This payee has \(linked.count) linked transaction(s). Reassign them before deleting.")
        }

        try await repository.delete(id)
    }
}
