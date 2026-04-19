import Foundation
import SwiftData

@ModelActor
actor SwiftDataTransactionRepository: TransactionRepository {
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        let models: [SDTransaction]

        if let filter = filter {
            models = try fetchFiltered(filter)
        } else {
            let descriptor = FetchDescriptor<SDTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            models = try modelContext.fetch(descriptor)
        }

        return models.map(TransactionMapper.toEntity)
    }

    // PERF-05: Push all supported dimensions to SQLite via a single #Predicate.
    // Tags and amountRange are post-filtered because SwiftData cannot express
    // array-element membership or Decimal ordering in SQLite.
    private func fetchFiltered(_ filter: TransactionFilter) throws -> [SDTransaction] {
        let hasDateRange = filter.dateRange != nil
        let startDate: Date = filter.dateRange?.lowerBound ?? .distantPast
        let endDate: Date = filter.dateRange?.upperBound ?? .distantFuture

        let hasTypes = !(filter.types?.isEmpty ?? true)
        let typeValues: [String] = filter.types?.map(\.rawValue) ?? []

        let hasCats = !(filter.categoryIDs?.isEmpty ?? true)
        let catIDs: [UUID] = filter.categoryIDs.map(Array.init) ?? []
        let catSentinel = UUID()

        let hasAccs = !(filter.accountIDs?.isEmpty ?? true)
        let accIDs: [UUID] = filter.accountIDs.map(Array.init) ?? []
        let accSentinel = UUID()

        let hasPayees = !(filter.payeeIDs?.isEmpty ?? true)
        let payeeIDArr: [UUID] = filter.payeeIDs.map(Array.init) ?? []
        let payeeSentinel = UUID()

        let hasQuery = !(filter.searchQuery?.isEmpty ?? true)
        let query: String = filter.searchQuery ?? ""

        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { tx in
                (!hasDateRange || (tx.date >= startDate && tx.date <= endDate)) &&
                (!hasTypes || typeValues.contains(tx.typeRawValue)) &&
                (!hasCats || catIDs.contains(tx.categoryID ?? catSentinel)) &&
                (!hasAccs || accIDs.contains(tx.accountID ?? accSentinel)) &&
                (!hasPayees || payeeIDArr.contains(tx.payeeID ?? payeeSentinel)) &&
                (!hasQuery || tx.note?.localizedStandardContains(query) == true)
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        // Limit how many rows we pull when doing a note search with no date range
        if hasQuery && !hasDateRange {
            descriptor.fetchLimit = 200
        }

        var results = try modelContext.fetch(descriptor)

        // Decimal comparisons cannot be expressed as SwiftData predicates
        if let amountRange = filter.amountRange {
            results = results.filter { amountRange.contains($0.amount) }
        }

        // [String] array field – must remain as a post-filter
        if let tags = filter.tags, !tags.isEmpty {
            results = results.filter { !tags.isDisjoint(with: Set($0.tags)) }
        }

        return results
    }

    func fetchByID(_ id: UUID) async throws -> TransactionEntity? {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return TransactionMapper.toEntity(model)
    }

    func create(_ entity: TransactionEntity) async throws {
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
            recurringRuleID: entity.recurringRuleID
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ entity: TransactionEntity) async throws {
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

    func delete(_ id: UUID) async throws {
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
    func bulkDelete(_ ids: [UUID]) async throws {
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

    // PERF-06: Push the note search to SQLite and cap results at 100 rows.
    func search(query: String) async throws -> [TransactionEntity] {
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.note?.localizedStandardContains(query) == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
    }
}
