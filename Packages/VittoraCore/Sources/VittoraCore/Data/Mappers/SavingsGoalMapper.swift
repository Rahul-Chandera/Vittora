import Foundation

public enum SavingsGoalMapper {
    public nonisolated static func toEntity(_ model: SDSavingsGoal) -> SavingsGoalEntity {
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
            isEmergencyFund: model.isEmergencyFund,
            colorHex: model.colorHex,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public nonisolated static func updateModel(_ model: SDSavingsGoal, from entity: SavingsGoalEntity) {
        model.name = entity.name
        model.category = entity.category
        model.targetAmount = entity.targetAmount
        model.currentAmount = entity.currentAmount
        model.targetDate = entity.targetDate
        model.linkedAccountID = entity.linkedAccountID
        model.note = entity.note
        model.status = entity.status
        model.isEmergencyFund = entity.isEmergencyFund
        model.colorHex = entity.colorHex
        model.updatedAt = .now
    }
}
