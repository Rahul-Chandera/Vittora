import Foundation
import SwiftData

enum RecurringRuleMapper {
    static func toEntity(_ model: SDRecurringRule) -> RecurringRuleEntity {
        RecurringRuleEntity(
            id: model.id,
            frequency: model.frequency,
            nextDate: model.nextDate,
            isActive: model.isActive,
            endDate: model.endDate,
            templateAmount: model.templateAmount,
            templateNote: model.templateNote,
            templateCategoryID: model.templateCategoryID,
            templateAccountID: model.templateAccountID,
            templatePayeeID: model.templatePayeeID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func updateModel(_ model: SDRecurringRule, from entity: RecurringRuleEntity) {
        model.frequency = entity.frequency
        model.nextDate = entity.nextDate
        model.isActive = entity.isActive
        model.endDate = entity.endDate
        model.templateAmount = entity.templateAmount
        model.templateNote = entity.templateNote
        model.templateCategoryID = entity.templateCategoryID
        model.templateAccountID = entity.templateAccountID
        model.templatePayeeID = entity.templatePayeeID
        model.updatedAt = .now
    }
}
