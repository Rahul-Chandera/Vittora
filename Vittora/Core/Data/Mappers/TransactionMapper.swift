import Foundation
import SwiftData

enum TransactionMapper {
    nonisolated static func toEntity(_ model: SDTransaction) -> TransactionEntity {
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
            transferPairID: model.transferPairID,
            transferDirection: model.transferDirection,
            documentIDs: [],
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDTransaction, from entity: TransactionEntity) {
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
        model.transferPairID = entity.transferPairID
        model.transferDirection = entity.transferDirection
        model.updatedAt = .now
    }
}
