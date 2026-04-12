import Foundation
import SwiftData

enum TransactionMapper {
    static func toEntity(_ model: SDTransaction) -> TransactionEntity {
        TransactionEntity(
            id: model.id,
            amount: model.amount,
            date: model.date,
            note: model.note,
            type: model.type,
            paymentMethod: model.paymentMethod,
            currencyCode: model.currencyCode,
            tags: model.tags,
            categoryID: model.categoryID,
            accountID: model.accountID,
            payeeID: model.payeeID,
            destinationAccountID: model.destinationAccountID,
            recurringRuleID: model.recurringRuleID,
            documentIDs: [],
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func updateModel(_ model: SDTransaction, from entity: TransactionEntity) {
        model.amount = entity.amount
        model.date = entity.date
        model.note = entity.note
        model.type = entity.type
        model.paymentMethod = entity.paymentMethod
        model.currencyCode = entity.currencyCode
        model.tags = entity.tags
        model.categoryID = entity.categoryID
        model.accountID = entity.accountID
        model.payeeID = entity.payeeID
        model.destinationAccountID = entity.destinationAccountID
        model.recurringRuleID = entity.recurringRuleID
        model.updatedAt = .now
    }
}
