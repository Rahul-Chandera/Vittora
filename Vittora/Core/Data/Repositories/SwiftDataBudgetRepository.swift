import Foundation
import SwiftData

@ModelActor
actor SwiftDataBudgetRepository: BudgetRepository {
    func fetchAll() async throws -> [BudgetEntity] {
        let descriptor = FetchDescriptor<SDBudget>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(BudgetMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> BudgetEntity? {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return BudgetMapper.toEntity(model)
    }

    func create(_ entity: BudgetEntity) async throws {
        let model = SDBudget(
            id: entity.id,
            amount: entity.amount,
            spent: entity.spent,
            period: entity.period,
            startDate: entity.startDate,
            rollover: entity.rollover,
            categoryID: entity.categoryID,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ entity: BudgetEntity) async throws {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { $0.id == entity.id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Budget not found"))
        }
        BudgetMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Budget not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    func fetchActive() async throws -> [BudgetEntity] {
        let now = Date()
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { budget in
                budget.startDate <= now && (budget.periodRawValue != "" || true)
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(BudgetMapper.toEntity)
    }

    func fetchForCategory(_ categoryID: UUID, period: BudgetPeriod) async throws -> BudgetEntity? {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { budget in
                budget.categoryID == categoryID && budget.periodRawValue == period.rawValue
            }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return BudgetMapper.toEntity(model)
    }
}
