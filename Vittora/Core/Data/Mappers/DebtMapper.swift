import Foundation
import SwiftData

enum DebtMapper {
    /// Merges the V5 `linkedTransactionIDs` array with the legacy single
    /// `linkedTransactionID` so pre-migration rows still surface all links.
    nonisolated static func linkedTransactionIDs(from model: SDDebt) -> [UUID] {
        if !model.linkedTransactionIDs.isEmpty {
            return model.linkedTransactionIDs
        }
        if let legacy = model.linkedTransactionID {
            return [legacy]
        }
        return []
    }

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
            linkedTransactionIDs: linkedTransactionIDs(from: model),
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
        model.linkedTransactionIDs = entity.linkedTransactionIDs
        model.linkedTransactionID = nil
        model.updatedAt = .now
    }
}
