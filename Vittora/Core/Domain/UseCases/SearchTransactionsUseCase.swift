import Foundation
import VittoraCore

struct SearchTransactionsUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let payeeRepository: any PayeeRepository

    nonisolated init(
        transactionRepository: any TransactionRepository,
        categoryRepository: any CategoryRepository,
        payeeRepository: any PayeeRepository
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.payeeRepository = payeeRepository
    }

    /// Matches a transaction if the query appears in its note, its category name,
    /// its payee name, or equals its amount. Results are de-duplicated and sorted
    /// newest-first.
    func execute(query: String) async throws -> [TransactionEntity] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var byID: [UUID: TransactionEntity] = [:]

        // Note text (repository predicate).
        for transaction in try await transactionRepository.search(query: trimmed) {
            byID[transaction.id] = transaction
        }

        // Category name.
        let categoryIDs = try await categoryRepository.fetchAll()
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .map(\.id)
        if !categoryIDs.isEmpty {
            for transaction in try await transactionRepository.fetchAll(
                filter: TransactionFilter(categoryIDs: Set(categoryIDs))
            ) {
                byID[transaction.id] = transaction
            }
        }

        // Payee name.
        let payeeIDs = try await payeeRepository.fetchAll()
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .map(\.id)
        if !payeeIDs.isEmpty {
            for transaction in try await transactionRepository.fetchAll(
                filter: TransactionFilter(payeeIDs: Set(payeeIDs))
            ) {
                byID[transaction.id] = transaction
            }
        }

        // Amount: exact numeric match, ignoring grouping separators.
        // ponytail: exact match only; add prefix/partial amount matching if asked.
        let numeric = trimmed.replacingOccurrences(of: ",", with: "")
        if let amount = Decimal(string: numeric) {
            for transaction in try await transactionRepository.fetchAll(
                filter: TransactionFilter(amountRange: amount...amount)
            ) {
                byID[transaction.id] = transaction
            }
        }

        return byID.values.sorted { $0.date > $1.date }
    }
}
