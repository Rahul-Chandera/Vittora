import Foundation
import SwiftData

@ModelActor
actor SwiftDataTransactionRepository: TransactionRepository {
    func fetchAll(filter: TransactionFilter?) async throws -> [TransactionEntity] {
        var descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        if let filter = filter {
            var predicates: [Predicate<SDTransaction>] = []

            if let startDate = filter.startDate {
                predicates.append(#Predicate { $0.date >= startDate })
            }

            if let endDate = filter.endDate {
                predicates.append(#Predicate { $0.date <= endDate })
            }

            if let categoryID = filter.categoryID {
                predicates.append(#Predicate { $0.categoryID == categoryID })
            }

            if let accountID = filter.accountID {
                predicates.append(#Predicate { $0.accountID == accountID })
            }

            if let type = filter.transactionType {
                predicates.append(#Predicate { $0.typeRawValue == type.rawValue })
            }

            if !predicates.isEmpty {
                descriptor.predicate = predicates.reduce(nil) { current, new in
                    if let current = current {
                        return #Predicate { $0 in
                            try current.evaluate($0) && try new.evaluate($0)
                        }
                    }
                    return new
                }
            }
        }

        let models = try modelContext.fetch(descriptor)
        return models.map(TransactionMapper.toEntity)
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
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.id == entity.id }
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
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { transaction in
                transaction.note?.localizedStandardContains(query) ?? false
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(TransactionMapper.toEntity)
    }
}
