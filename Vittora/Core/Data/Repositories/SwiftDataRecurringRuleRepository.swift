import Foundation
import SwiftData

@ModelActor
actor SwiftDataRecurringRuleRepository: RecurringRuleRepository {
    func fetchAll() async throws -> [RecurringRuleEntity] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> RecurringRuleEntity? {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return RecurringRuleMapper.toEntity(model)
    }

    func create(_ entity: RecurringRuleEntity) async throws {
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

    func update(_ entity: RecurringRuleEntity) async throws {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == entity.id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
        RecurringRuleMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    func fetchActive() async throws -> [RecurringRuleEntity] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }

    func fetchDueRules(before date: Date) async throws -> [RecurringRuleEntity] {
        let descriptor = FetchDescriptor<SDRecurringRule>(
            predicate: #Predicate { rule in
                rule.isActive == true && rule.nextDate <= date
            },
            sortBy: [SortDescriptor(\.nextDate, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(RecurringRuleMapper.toEntity)
    }
}
