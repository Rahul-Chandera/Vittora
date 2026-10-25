import Foundation
import VittoraCore

/// A read-only view of the ledger with every amount expressed in the user's main
/// currency, for code that adds transactions up: reports, Ask About Your Money, the
/// India filing pack.
///
/// A transaction in another currency comes back converted, with the main currency's
/// code, when a rate exists; without one it comes back unchanged, so code that filters
/// by currency still leaves it out and says so.
///
/// Writes throw. Anything that edits must use the real repository: saving a converted
/// copy would overwrite the amount the user actually entered.
nonisolated struct ConvertingTransactionRepository: TransactionRepository {
    enum ConversionError: LocalizedError {
        case readOnly
        var errorDescription: String? { String(localized: "This view of the ledger is read-only.") }
    }

    let base: any TransactionRepository
    let store: ExchangeRateStore

    private func converted(_ transactions: [TransactionEntity]) -> [TransactionEntity] {
        let target = store.baseCurrency
        guard transactions.contains(where: { $0.currencyCode != target }) else { return transactions }
        let rates = store.rates
        return transactions.map { transaction in
            guard transaction.currencyCode != target,
                  let amount = rates.convert(transaction.amount, from: transaction.currencyCode, to: target)
            else { return transaction }
            var copy = transaction
            copy.amount = amount
            copy.currencyCode = target
            return copy
        }
    }

    func fetchTransactionCount() async throws -> Int { try await base.fetchTransactionCount() }
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        converted(try await base.fetchAll(filter: filter))
    }
    func fetchPage(filter: TransactionFilter?, offset: Int, limit: Int) async throws -> [TransactionEntity] {
        converted(try await base.fetchPage(filter: filter, offset: offset, limit: limit))
    }
    func fetchAllForReconciliation() async throws -> [TransactionEntity] {
        converted(try await base.fetchAllForReconciliation())
    }
    func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        try await base.fetchByID(id).map { converted([$0])[0] }
    }
    func fetchForAccount(id: UUID, limit: Int) async throws -> [TransactionEntity] {
        converted(try await base.fetchForAccount(id: id, limit: limit))
    }
    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity] {
        converted(try await base.fetchForRecurringRule(id))
    }
    func hasTransactions(forAccountID id: UUID) async throws -> Bool { try await base.hasTransactions(forAccountID: id) }
    func search(query: String) async throws -> [TransactionEntity] { converted(try await base.search(query: query)) }
    func fetchExternalIDs(withPrefix prefix: String) async throws -> Set<String> {
        try await base.fetchExternalIDs(withPrefix: prefix)
    }

    func create(_ entity: TransactionEntity) async throws { throw ConversionError.readOnly }
    func update(_ entity: TransactionEntity) async throws { throw ConversionError.readOnly }
    func delete(_ id: UUID) async throws { throw ConversionError.readOnly }
    func bulkDelete(_ ids: [UUID]) async throws { throw ConversionError.readOnly }
}

extension NetWorthSummary {
    /// Net worth in `target`, adding every currency that has a rate. `missing` lists the
    /// currencies left out for want of one, so the screen can say so.
    func converted(to target: String, using rates: ExchangeRates) -> (total: Decimal, missing: [String]) {
        var total = Decimal(0)
        var missing: [String] = []
        for totals in byCurrency {
            if let value = rates.convert(totals.netWorth, from: totals.currencyCode, to: target) {
                total += value
            } else {
                missing.append(totals.currencyCode)
            }
        }
        return (total, missing)
    }
}
