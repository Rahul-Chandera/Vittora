import Foundation
import SwiftData

public enum TransactionMapper {
    public nonisolated static func toEntity(_ model: SDTransaction) -> TransactionEntity {
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
            categorySuggestion: model.categorySuggestion,
            documentIDs: [],
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public nonisolated static func updateModel(_ model: SDTransaction, from entity: TransactionEntity) {
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
        // categorySuggestion is deliberately write-once at creation and is NOT
        // updated here. It records what the categorizer proposed when the row was
        // first entered; an edit that re-categorises the row is precisely the
        // override signal we want to keep, and rewriting the suggestion on save
        // would erase it. The edit path also builds a fresh entity with no
        // suggestion, so assigning here would blank the column on every edit.
        model.updatedAt = .now
    }
}
