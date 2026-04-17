import Foundation

enum SavingsGoalMapper {
    nonisolated static func toEntity(_ model: SDSavingsGoal) -> SavingsGoalEntity {
        SavingsGoalEntity(
            id: model.id,
            name: model.name,
            category: model.category,
            targetAmount: model.targetAmount,
            currentAmount: model.currentAmount,
            targetDate: model.targetDate,
            linkedAccountID: model.linkedAccountID,
            note: model.note,
            status: model.status,
            colorHex: model.colorHex,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDSavingsGoal, from entity: SavingsGoalEntity) {
        model.name = entity.name
        model.category = entity.category
        model.targetAmount = entity.targetAmount
        model.currentAmount = entity.currentAmount
        model.targetDate = entity.targetDate
        model.linkedAccountID = entity.linkedAccountID
        model.note = entity.note
        model.status = entity.status
        model.colorHex = entity.colorHex
        model.updatedAt = .now
    }
}
