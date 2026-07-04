import Foundation
import SwiftData

@ModelActor
public actor SwiftDataRecurringRuleRepository: RecurringRuleRepository {
    public func fetchAll() async throws -> [RecurringRuleEntity] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }

    public func fetchByID(_ id: UUID) async throws -> RecurringRuleEntity? {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return RecurringRuleMapper.toEntity(model)
    }

    public func create(_ entity: RecurringRuleEntity) async throws {
        let model = SDRecurringRule(
            id: entity.id,
            frequency: entity.frequency,
            nextDate: entity.nextDate,
            isActive: entity.isActive,
            endDate: entity.endDate,
            templateAmount: entity.templateAmount,
            templateNote: entity.templateNote,
            templateCategoryID: entity.templateCategoryID,
            templateAccountID: entity.templateAccountID,
            templatePayeeID: entity.templatePayeeID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ entity: RecurringRuleEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
        RecurringRuleMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func fetchActive() async throws -> [RecurringRuleEntity] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }

    public func fetchDueRules(before date: Date) async throws -> [RecurringRuleEntity] {
        let dueDate = date
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { rule in
                rule.isActive == true && rule.nextDate <= dueDate
            },
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }
}
