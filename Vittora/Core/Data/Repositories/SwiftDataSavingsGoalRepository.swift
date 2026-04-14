import Foundation
import SwiftData

@ModelActor
actor SwiftDataSavingsGoalRepository: SavingsGoalRepository {

    func fetchAll() async throws -> [SavingsGoalEntity] {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(SavingsGoalMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> SavingsGoalEntity? {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(SavingsGoalMapper.toEntity)
    }

    func fetchActive() async throws -> [SavingsGoalEntity] {
        let descriptor = FetchDescriptor<SDSavingsGoal>(
            predicate: #Predicate { $0.statusRawValue == "active" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(SavingsGoalMapper.toEntity)
    }

    func create(_ goal: SavingsGoalEntity) async throws {
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

    func update(_ goal: SavingsGoalEntity) async throws {
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

    func delete(_ id: UUID) async throws {
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
