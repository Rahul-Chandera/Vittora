import Foundation

public struct TransactionFilter: Sendable, Equatable {
    public nonisolated var dateRange: ClosedRange<Date>?
    public nonisolated var types: Set<TransactionType>?
    public nonisolated var categoryIDs: Set<UUID>?
    public nonisolated var accountIDs: Set<UUID>?
    public nonisolated var payeeIDs: Set<UUID>?
    public nonisolated var amountRange: ClosedRange<Decimal>?
    public nonisolated var searchQuery: String?
    public nonisolated var tags: Set<String>?

    public nonisolated init(
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
