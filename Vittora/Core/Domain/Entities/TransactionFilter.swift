import Foundation

struct TransactionFilter: Sendable, Equatable {
    var dateRange: ClosedRange<Date>?
    var types: Set<TransactionType>?
    var categoryIDs: Set<UUID>?
    var accountIDs: Set<UUID>?
    var payeeIDs: Set<UUID>?
    var amountRange: ClosedRange<Decimal>?
    var searchQuery: String?
    var tags: Set<String>?

    init(
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
