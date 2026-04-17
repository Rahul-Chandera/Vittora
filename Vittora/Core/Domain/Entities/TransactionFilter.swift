import Foundation

struct TransactionFilter: Sendable, Equatable {
    nonisolated var dateRange: ClosedRange<Date>?
    nonisolated var types: Set<TransactionType>?
    nonisolated var categoryIDs: Set<UUID>?
    nonisolated var accountIDs: Set<UUID>?
    nonisolated var payeeIDs: Set<UUID>?
    nonisolated var amountRange: ClosedRange<Decimal>?
    nonisolated var searchQuery: String?
    nonisolated var tags: Set<String>?

    nonisolated init(
        dateRange: ClosedRange<Date>? = nil,
        types: Set<TransactionType>? = nil,
        categoryIDs: Set<UUID>? = nil,
        accountIDs: Set<UUID>? = nil,
        payeeIDs: Set<UUID>? = nil,
        amountRange: ClosedRange<Decimal>? = nil,
        searchQuery: String? = nil,
        tags: Set<String>? = nil
    ) {
        self.dateRange = dateRange
        self.types = types
        self.categoryIDs = categoryIDs
        self.accountIDs = accountIDs
        self.payeeIDs = payeeIDs
        self.amountRange = amountRange
        self.searchQuery = searchQuery
        self.tags = tags
    }
}
