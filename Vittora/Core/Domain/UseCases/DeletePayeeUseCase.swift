import Foundation
import VittoraCore

struct DeletePayeeUseCase: Sendable {
    private let repository: any PayeeRepository
    private let transactionRepository: any TransactionRepository
    /// Unlinking the payee's transactions and deleting it persist in one save.
    private let ledgerWriting: any LedgerWriting

    nonisolated init(
        repository: any PayeeRepository,
        transactionRepository: any TransactionRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
        self.ledgerWriting = ledgerWriting
    }

    /// How many transactions will lose this payee, for the confirmation.
    // ponytail: filtered fetches are capped (defaultFilteredFetchLimit), so a
    // payee with more transactions than that reads as the cap. Display only —
    // the delete itself unlinks every one.
    func linkedTransactionCount(id: UUID) async throws -> Int {
        try await transactionRepository.fetchAll(filter: TransactionFilter(payeeIDs: [id])).count
    }

    /// Deletes the payee. Its transactions and recurring rules stay, without a
    /// payee; a payee with debt records is refused.
    func execute(id: UUID) async throws {
        guard (try await repository.fetchByID(id)) != nil else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
        try await ledgerWriting.performDeletePayee(payeeID: id)
    }
}
