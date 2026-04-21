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
        // PERF-05: Push date range to SQLite (most selective indexed dimension).
        // Type, category, account, payee, and text filters are applied in-memory
        // because compound optional-UUID predicates exceed Xcode 26's type-check budget.
        let startDate: Date = filter.dateRange?.lowerBound ?? .distantPast
        let endDate: Date = filter.dateRange?.upperBound ?? .distantFuture
        let hasDateRange = filter.dateRange != nil

        let predicate = #Predicate<SDTransaction> { tx in
            hasDateRange == false || (tx.date >= startDate && tx.date <= endDate)
        }
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        // Cap note-search queries when no date range narrows the scan.
        if filter.searchQuery != nil && !filter.searchQuery!.isEmpty && !hasDateRange {
            descriptor.fetchLimit = 200
        }

        var results = try modelContext.fetch(descriptor)

        if let types = filter.types, !types.isEmpty {
            let rawValues = Set(types.map(\.rawValue))
            results = results.filter { rawValues.contains($0.typeRawValue) }
        }
        if let catIDs = filter.categoryIDs, !catIDs.isEmpty {
            results = results.filter { $0.categoryID.map { catIDs.contains($0) } ?? false }
        }
        if let accIDs = filter.accountIDs, !accIDs.isEmpty {
            results = results.filter { $0.accountID.map { accIDs.contains($0) } ?? false }
        }
        if let payeeIDs = filter.payeeIDs, !payeeIDs.isEmpty {
            results = results.filter { $0.payeeID.map { payeeIDs.contains($0) } ?? false }
        }
        if let query = filter.searchQuery, !query.isEmpty {
            results = results.filter {
                $0.note?.localizedStandardContains(query) == true
            }
        }
        if let amountRange = filter.amountRange {
            results = results.filter { amountRange.contains($0.amount) }
        }
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

    func fetchForRecurringRule(_ id: UUID) async throws -> [TransactionEntity] {
        var descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.recurringRuleID == id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        return try modelContext.fetch(descriptor).map(TransactionMapper.toEntity)
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
