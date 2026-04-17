import Foundation
import SwiftData

enum BudgetMapper {
    nonisolated static func toEntity(_ model: SDBudget) -> BudgetEntity {
        BudgetEntity(
            id: model.id,
            amount: model.amount,
            spent: model.spent,
            period: model.period,
            startDate: model.startDate,
            rollover: model.rollover,
            categoryID: model.categoryID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDBudget, from entity: BudgetEntity) {
        model.amount = entity.amount
        model.spent = entity.spent
        model.period = entity.period
        model.startDate = entity.startDate
        model.rollover = entity.rollover
        model.categoryID = entity.categoryID
        model.updatedAt = .now
    }
}
