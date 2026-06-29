import Foundation
import VittoraCore

struct BulkOperationsUseCase: Sendable {
    let transactionRepository: any TransactionRepository

    nonisolated init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func recategorize(transactionIDs: [UUID], newCategoryID: UUID) async throws {
        for id in transactionIDs {
            guard let transaction = try await transactionRepository.fetchByID(id) else {
                throw VittoraError.notFound("Transaction not found")
            }

            var updatedTransaction = transaction
            updatedTransaction.categoryID = newCategoryID
            updatedTransaction.updatedAt = .now

            try await transactionRepository.update(updatedTransaction)
        }
    }

    // NOTE: bulk DELETE intentionally lives on `DeleteTransactionUseCase.executeBulk`,
    // which reverses balance effects (BOTH legs for a transfer) and removes rows
    // atomically through the ledger store (A4). The previous non-atomic,
    // transfer-unaware `bulkDelete` here was removed to keep a single safe path.

    func bulkTag(transactionIDs: [UUID], tag: String) async throws {
        for id in transactionIDs {
            guard let transaction = try await transactionRepository.fetchByID(id) else {
                throw VittoraError.notFound("Transaction not found")
            }

            var updatedTransaction = transaction
            updatedTransaction.updatedAt = .now

            // Append tag if not already present
            if !updatedTransaction.tags.contains(tag) {
                updatedTransaction.tags.append(tag)
            }

            try await transactionRepository.update(updatedTransaction)
        }
    }
}
