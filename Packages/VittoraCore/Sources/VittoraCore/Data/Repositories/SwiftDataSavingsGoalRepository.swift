import Foundation
import SwiftData

@ModelActor
public actor SwiftDataSavingsGoalRepository: SavingsGoalRepository {

    public func fetchAll() async throws -> [SavingsGoalEntity] {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(SavingsGoalMapper.toEntity)
    }

    public func fetchByID(_ id: UUID) async throws -> SavingsGoalEntity? {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(SavingsGoalMapper.toEntity)
    }

    public func fetchActive() async throws -> [SavingsGoalEntity] {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.statusRawValue == "active" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(SavingsGoalMapper.toEntity)
    }

    public func create(_ goal: SavingsGoalEntity) async throws {
        let model = SDSavingsGoal(
            id: goal.id,
            name: goal.name,
            category: goal.category,
            targetAmount: goal.targetAmount,
            currentAmount: goal.currentAmount,
            targetDate: goal.targetDate,
            linkedAccountID: goal.linkedAccountID,
            note: goal.note,
            status: goal.status,
            colorHex: goal.colorHex,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ goal: SavingsGoalEntity) async throws {
        let id = goal.id
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Savings goal not found"))
        }
        SavingsGoalMapper.updateModel(model, from: goal)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Savings goal not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }
}
