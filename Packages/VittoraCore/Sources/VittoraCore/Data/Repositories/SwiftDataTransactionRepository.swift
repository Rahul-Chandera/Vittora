import Foundation
import SwiftData

@ModelActor
public actor SwiftDataTransactionRepository: TransactionRepository {
    nonisolated private static let defaultFilteredFetchLimit = 500
    nonisolated private static let unscopedFilteredFetchLimit = 200
    nonisolated static let exportPageSize = 500

    public func fetchTransactionCount() async throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<SDTransaction>())
    }

    public func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        let models: [SDTransaction]

        if let filter = filter {
            models = try fetchFiltered(filter)
        } else {
            var descriptor = FetchDescriptor<SDTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            // PERF-12: unbounded history loads are capped; callers needing full sets should iterate.
            descriptor.fetchLimit = Self.defaultFilteredFetchLimit
            models = try modelContext.fetch(descriptor)
        }

        return models.map(TransactionMapper.toEntity)
    }

    public func fetchPage(filter: TransactionFilter?, offset: Int, limit: Int) async throws -> [TransactionEntity] {
        let clampedOffset = max(0, offset)
        let clampedLimit = max(1, limit)
        let models: [SDTransaction]

        if let filter {
            models = try fetchFiltered(filter, offset: clampedOffset, pageLimit: clampedLimit)
        } else {
            var descriptor = FetchDescriptor<SDTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchOffset = clampedOffset
            descriptor.fetchLimit = clampedLimit
            models = try modelContext.fetch(descriptor)
        }

        return models.map(TransactionMapper.toEntity)
    }

    // PERF-05: Push supported dimensions to SQLite where the predicate type-checker allows.
    // Tags and amountRange are post-filtered because SwiftData cannot express
    // array-element membership or Decimal ordering in SQLite.
    private func fetchFiltered(
        _ filter: TransactionFilter,
        offset: Int = 0,
        pageLimit: Int? = nil
    ) throws -> [SDTransaction] {
        let startDate = filter.dateRange?.lowerBound ?? .distantPast
        let endDate = filter.dateRange?.upperBound ?? .distantFuture
        let hasDateRange = filter.dateRange != nil
        let singleAccountID = filter.accountIDs.flatMap { $0.count == 1 ? $0.first : nil }
        let singleCategoryID = filter.categoryIDs.flatMap { $0.count == 1 ? $0.first : nil }
        let singleTypeRaw = filter.types.flatMap { $0.count == 1 ? $0.first?.rawValue : nil }
        let trimmedSearchQuery = filter.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSearchQuery = trimmedSearchQuery.map { !$0.isEmpty } ?? false

        var results: [SDTransaction]
        var needsInMemoryPagination = false

        func applyPagination(to descriptor: inout FetchDescriptor<SDTransaction>) {
            if let pageLimit {
                descriptor.fetchOffset = offset
                descriptor.fetchLimit = pageLimit
            }
        }

        func needsInMemoryPostFilter(_ filter: TransactionFilter) -> Bool {
            if let types = filter.types, types.count != 1 { return true }
            if let categoryIDs = filter.categoryIDs, categoryIDs.count != 1 { return true }
            if let accountIDs = filter.accountIDs, accountIDs.count != 1 { return true }
            if let payeeIDs = filter.payeeIDs, !payeeIDs.isEmpty { return true }
            if let tags = filter.tags, !tags.isEmpty { return true }
            if filter.amountRange != nil { return true }
            return false
        }

        if let accountID = singleAccountID, let typeRaw = singleTypeRaw, hasDateRange {
            let capturedAccountID = accountID
            let predicate = #Predicate<SDTransaction> { tx in
                (tx.accountID == capturedAccountID || tx.destinationAccountID == capturedAccountID)
                    && tx.typeRawValue == typeRaw
                    && tx.date >= startDate
                    && tx.date <= endDate
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else if let accountID = singleAccountID, hasDateRange {
            let capturedAccountID = accountID
            let predicate = #Predicate<SDTransaction> { tx in
                (tx.accountID == capturedAccountID || tx.destinationAccountID == capturedAccountID)
                    && tx.date >= startDate
                    && tx.date <= endDate
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else if let accountID = singleAccountID {
            let capturedAccountID = accountID
            let predicate = #Predicate<SDTransaction> { tx in
                tx.accountID == capturedAccountID || tx.destinationAccountID == capturedAccountID
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            if pageLimit == nil {
                descriptor.fetchLimit = Self.defaultFilteredFetchLimit
            }
            results = try modelContext.fetch(descriptor)
        } else if let categoryID = singleCategoryID, hasDateRange {
            let capturedCategoryID = categoryID
            let predicate = #Predicate<SDTransaction> { tx in
                tx.categoryID == capturedCategoryID
                    && tx.date >= startDate
                    && tx.date <= endDate
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else if let categoryID = singleCategoryID {
            let capturedCategoryID = categoryID
            let predicate = #Predicate<SDTransaction> { tx in
                tx.categoryID == capturedCategoryID
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            if pageLimit == nil {
                descriptor.fetchLimit = Self.defaultFilteredFetchLimit
            }
            results = try modelContext.fetch(descriptor)
        } else if let typeRaw = singleTypeRaw, hasDateRange {
            let predicate = #Predicate<SDTransaction> { tx in
                tx.typeRawValue == typeRaw
                    && tx.date >= startDate
                    && tx.date <= endDate
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else if let typeRaw = singleTypeRaw {
            let predicate = #Predicate<SDTransaction> { tx in
                tx.typeRawValue == typeRaw
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            if pageLimit == nil {
                descriptor.fetchLimit = Self.defaultFilteredFetchLimit
            }
            results = try modelContext.fetch(descriptor)
        } else if hasSearchQuery, let query = trimmedSearchQuery {
            let predicate = #Predicate<SDTransaction> { tx in
                tx.note?.localizedStandardContains(query) == true
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else if hasDateRange {
            let predicate = #Predicate<SDTransaction> { tx in
                tx.date >= startDate && tx.date <= endDate
            }
            var descriptor = FetchDescriptor<SDTransaction>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            results = try modelContext.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<SDTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            applyPagination(to: &descriptor)
            if pageLimit == nil, !needsInMemoryPostFilter(filter) {
                descriptor.fetchLimit = Self.unscopedFilteredFetchLimit
            }
            results = try modelContext.fetch(descriptor)
        }

        if let types = filter.types, types.count != 1 {
            needsInMemoryPagination = true
            let rawValues = Set(types.map(\.rawValue))
            results = results.filter { rawValues.contains($0.typeRawValue) }
        }
        if let catIDs = filter.categoryIDs, catIDs.count != 1 {
            needsInMemoryPagination = true
            results = results.filter { $0.categoryID.map { catIDs.contains($0) } ?? false }
        }
        if let accIDs = filter.accountIDs, accIDs.count != 1 {
            needsInMemoryPagination = true
            results = results.filter {
                $0.accountID.map { accIDs.contains($0) } == true
                    || $0.destinationAccountID.map { accIDs.contains($0) } == true
            }
        }
        if let payeeIDs = filter.payeeIDs, !payeeIDs.isEmpty {
            needsInMemoryPagination = true
            results = results.filter { $0.payeeID.map { payeeIDs.contains($0) } ?? false }
        }
        let searchCombinedWithOtherFilters = hasSearchQuery
            && (hasDateRange
                || filter.types != nil
                || filter.categoryIDs != nil
                || filter.accountIDs != nil
                || filter.payeeIDs != nil
                || filter.tags != nil
                || filter.amountRange != nil)
        if searchCombinedWithOtherFilters, let query = trimmedSearchQuery {
            needsInMemoryPagination = true
            results = results.filter {
                $0.note?.localizedStandardContains(query) == true
            }
        }
        if let amountRange = filter.amountRange {
            needsInMemoryPagination = true
            results = results.filter { amountRange.contains($0.amount) }
        }
        if let tags = filter.tags, !tags.isEmpty {
            needsInMemoryPagination = true
            results = results.filter { !tags.isDisjoint(with: Set($0.tags)) }
        }

        if let pageLimit, needsInMemoryPagination {
            let start = min(max(0, offset), results.count)
            let end = min(start + pageLimit, results.count)
            results = Array(results[start..<end])
        }

        return results
    }

    // DATAINTEGRITY-12: reconciliation needs every row, so this path is
    // deliberately uncapped (the 500-row cap on `fetchAll` would truncate sums).
    public func fetchAllForReconciliation() async throws -> [TransactionEntity] {
        let descriptor = FetchDescriptor<SDTransaction>()
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
    }

    public func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return TransactionMapper.toEntity(model)
    }

    public func fetchForAccount(id: UUID, limit: Int) async throws -> [TransactionEntity] {
        let accountID = id
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { tx in
                tx.accountID == accountID || tx.destinationAccountID == accountID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = max(1, limit)
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
    }

    /// All occurrences for a recurring rule. Must be uncapped: catch-up
    /// generation keys idempotency off this set, and a stale `nextDate` after an
    /// interrupted run can legitimately span more than a page of history. A
    /// `fetchLimit` here silently drops older days and double-charges on retry.
    public func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.recurringRuleID == id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
    }

    public func hasTransactions(forAccountID id: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.accountID == id || $0.destinationAccountID == id }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    public func create(_ entity: TransactionEntity) async throws {
        let model = SDTransaction(
            id: entity.id,
            amount: entity.amount,
            date: entity.date,
            note: entity.note,
            type: entity.type,
            paymentMethod: entity.paymentMethod,
            currencyCode: entity.currencyCode,
            tags: entity.tags,
            categoryID: entity.categoryID,
            accountID: entity.accountID,
            payeeID: entity.payeeID,
            destinationAccountID: entity.destinationAccountID,
            recurringRuleID: entity.recurringRuleID,
            transferPairID: entity.transferPairID,
            transferDirection: entity.transferDirection
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ entity: TransactionEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }
        TransactionMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    // PERF-07: Delete all rows first, then save once instead of one save per row.
    public func bulkDelete(_ ids: [UUID]) async throws {
        for id in ids {
            let descriptor = FetchDescriptor<SDTransaction>(
                predicate: #Predicate { $0.id == id }
            )
            if let model = try modelContext.fetch(descriptor).first {
                modelContext.delete(model)
            }
        }
        try modelContext.save()
    }

    // PERF-06: Push note search to SQLite (uncapped — predicate bounds the scan).
    public func search(query: String) async throws -> [TransactionEntity] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.note?.localizedStandardContains(query) == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
    }
}
