import Foundation
import VittoraCore

enum TransactionEditField: String, Codable, Sendable, CaseIterable {
    case amount
    case date
    case type
    case category
    case account
    case payee
    case note
    case tags
    case paymentMethod
}

struct TransactionFieldChange: Codable, Sendable, Equatable {
    let field: TransactionEditField
    let previousValue: String?
    let newValue: String?
}

struct TransactionEditRecord: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let transactionID: UUID
    let editedAt: Date
    let changes: [TransactionFieldChange]

    init(
        id: UUID = UUID(),
        transactionID: UUID,
        editedAt: Date = .now,
        changes: [TransactionFieldChange]
    ) {
        self.id = id
        self.transactionID = transactionID
        self.editedAt = editedAt
        self.changes = changes
    }
}

enum TransactionEditDiff {
    nonisolated static func changes(from before: TransactionEntity, to after: TransactionEntity) -> [TransactionFieldChange] {
        var result: [TransactionFieldChange] = []

        if before.amount != after.amount {
            result.append(TransactionFieldChange(
                field: .amount,
                previousValue: "\(before.amount)",
                newValue: "\(after.amount)"
            ))
        }
        if before.date != after.date {
            result.append(TransactionFieldChange(
                field: .date,
                previousValue: ISO8601DateFormatter().string(from: before.date),
                newValue: ISO8601DateFormatter().string(from: after.date)
            ))
        }
        if before.type != after.type {
            result.append(TransactionFieldChange(
                field: .type,
                previousValue: before.type.rawValue,
                newValue: after.type.rawValue
            ))
        }
        if before.categoryID != after.categoryID {
            result.append(TransactionFieldChange(
                field: .category,
                previousValue: before.categoryID?.uuidString,
                newValue: after.categoryID?.uuidString
            ))
        }
        if before.accountID != after.accountID {
            result.append(TransactionFieldChange(
                field: .account,
                previousValue: before.accountID?.uuidString,
                newValue: after.accountID?.uuidString
            ))
        }
        if before.payeeID != after.payeeID {
            result.append(TransactionFieldChange(
                field: .payee,
                previousValue: before.payeeID?.uuidString,
                newValue: after.payeeID?.uuidString
            ))
        }
        if before.note != after.note {
            result.append(TransactionFieldChange(
                field: .note,
                previousValue: before.note,
                newValue: after.note
            ))
        }
        if before.tags != after.tags {
            result.append(TransactionFieldChange(
                field: .tags,
                previousValue: before.tags.joined(separator: ", "),
                newValue: after.tags.joined(separator: ", ")
            ))
        }
        if before.paymentMethod != after.paymentMethod {
            result.append(TransactionFieldChange(
                field: .paymentMethod,
                previousValue: before.paymentMethod.rawValue,
                newValue: after.paymentMethod.rawValue
            ))
        }

        return result
    }
}
