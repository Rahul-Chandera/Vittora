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

    private func fetchFiltered(_ filter: TransactionFilter) throws -> [SDTransaction] {
        // Build individual fetch based on the most selective filter
        // SwiftData #Predicate doesn't support dynamic composition,
        // so we fetch with the primary filter and post-filter in memory for the rest
        var descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        // Apply date range predicate if available (most common filter)
        if let dateRange = filter.dateRange {
            let startDate = dateRange.lowerBound
            let endDate = dateRange.upperBound
            descriptor.predicate = #Predicate<SDTransaction> { transaction in
                transaction.date >= startDate && transaction.date <= endDate
            }
        }

        var results = try modelContext.fetch(descriptor)

        // Post-filter by types
        if let types = filter.types, !types.isEmpty {
            let typeRawValues = types.map(\.rawValue)
            results = results.filter { typeRawValues.contains($0.typeRawValue) }
        }

        // Post-filter by category IDs
        if let categoryIDs = filter.categoryIDs, !categoryIDs.isEmpty {
            results = results.filter { transaction in
                guard let catID = transaction.categoryID else { return false }
                return categoryIDs.contains(catID)
            }
        }

        // Post-filter by account IDs
        if let accountIDs = filter.accountIDs, !accountIDs.isEmpty {
            results = results.filter { transaction in
                guard let accID = transaction.accountID else { return false }
                return accountIDs.contains(accID)
            }
        }

        // Post-filter by payee IDs
        if let payeeIDs = filter.payeeIDs, !payeeIDs.isEmpty {
            results = results.filter { transaction in
                guard let payID = transaction.payeeID else { return false }
                return payeeIDs.contains(payID)
            }
        }

        // Post-filter by amount range
        if let amountRange = filter.amountRange {
            results = results.filter { amountRange.contains($0.amount) }
        }

        // Post-filter by search query
        if let query = filter.searchQuery, !query.isEmpty {
            results = results.filter { transaction in
                transaction.note?.localizedCaseInsensitiveContains(query) ?? false
            }
        }

        // Post-filter by tags
        if let tags = filter.tags, !tags.isEmpty {
            results = results.filter { transaction in
                !tags.isDisjoint(with: Set(transaction.tags))
            }
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

    func bulkDelete(_ ids: [UUID]) async throws {
        for id in ids {
            try await delete(id)
        }
    }

    func search(query: String) async throws -> [TransactionEntity] {
        // Fetch all and filter in memory since #Predicate has
        // limited support for optional string contains
        let descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        let filtered = models.filter { transaction in
            transaction.note?.localizedCaseInsensitiveContains(query) ?? false
        }
        return filtered.map(TransactionMapper.toEntity)
    }
}
