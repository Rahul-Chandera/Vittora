import Foundation
import SwiftData

enum DebtMapper {
    nonisolated static func toEntity(_ model: SDDebt) -> DebtEntry {
        DebtEntry(
            id: model.id,
            payeeID: model.payeeID,
            amount: model.amount,
            settledAmount: model.settledAmount,
            direction: model.direction,
            dueDate: model.dueDate,
            note: model.note,
            isSettled: model.isSettled,
            linkedTransactionID: model.linkedTransactionID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDDebt, from entity: DebtEntry) {
        model.payeeID = entity.payeeID
        model.amount = entity.amount
        model.settledAmount = entity.settledAmount
        model.direction = entity.direction
        model.dueDate = entity.dueDate
        model.note = entity.note
        model.isSettled = entity.isSettled
        model.linkedTransactionID = entity.linkedTransactionID
        model.updatedAt = .now
    }
}
