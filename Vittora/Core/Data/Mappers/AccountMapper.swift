import Foundation
import SwiftData

enum AccountMapper {
    nonisolated static func toEntity(_ model: SDAccount) -> AccountEntity {
        AccountEntity(
            id: model.id,
            name: model.name,
            type: model.type,
            balance: model.balance,
            currencyCode: model.currencyCode,
            icon: model.icon,
            isArchived: model.isArchived,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDAccount, from entity: AccountEntity) {
        model.name = entity.name
        model.type = entity.type
        model.balance = entity.balance
        model.currencyCode = entity.currencyCode
        model.icon = entity.icon
        model.isArchived = entity.isArchived
        model.updatedAt = .now
    }
}
