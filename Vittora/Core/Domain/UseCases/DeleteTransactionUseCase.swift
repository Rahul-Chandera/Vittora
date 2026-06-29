import Foundation

struct DeleteTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let documentRepository: any DocumentRepository
    let documentStorageService: any DocumentStorageServiceProtocol
    /// REQUIRED, non-optional: deleting a transaction reverses its balance effect
    /// (BOTH legs for an A3 transfer) and removes the row(s) in one save. Routing
    /// through the ledger store keeps that atomic (DATAINTEGRITY-1/2, A4).
    let ledgerWriting: any LedgerWriting

    nonisolated init(
        transactionRepository: any TransactionRepository,
        documentRepository: any DocumentRepository,
        documentStorageService: any DocumentStorageServiceProtocol,
        ledgerWriting: any LedgerWriting
    ) {
        self.transactionRepository = transactionRepository
        self.documentRepository = documentRepository
        self.documentStorageService = documentStorageService
        self.ledgerWriting = ledgerWriting
    }

    func execute(id: UUID) async throws {
        // Confirm the transaction exists before touching documents.
        guard try await transactionRepository.fetchByID(id) != nil else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }

        // Delete linked documents first to avoid orphaned encrypted payloads.
        let linkedDocuments = try await documentRepository.fetchForTransaction(id)
        let deleteDocumentUseCase = DeleteDocumentUseCase(
            documentRepository: documentRepository,
            documentStorageService: documentStorageService
        )
        for document in linkedDocuments {
            try await deleteDocumentUseCase.execute(id: document.id)
        }

        // Reverse balance effect(s) and delete the row(s) atomically. For an A3
        // transfer this removes BOTH paired legs and reverses both balances.
        try await ledgerWriting.performDelete(transactionID: id)
    }

    func executeBulk(ids: [UUID]) async throws {
        for id in ids {
            // Deleting one transfer leg also removes its paired partner, so a
            // partner id later in the batch may already be gone — skip it rather
            // than failing the whole bulk delete.
            guard try await transactionRepository.fetchByID(id) != nil else { continue }
            try await execute(id: id)
        }
    }
}
