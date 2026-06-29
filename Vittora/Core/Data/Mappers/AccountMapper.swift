import Foundation
import SwiftData
import VittoraCore

enum AccountMapper {
    nonisolated static func toEntity(_ model: SDAccount) -> AccountEntity {
        AccountEntity(
            id: model.id,
            name: model.name,
            type: model.type,
            balance: model.balance,
            openingBalance: model.openingBalance,
            currencyCode: model.currencyCode,
            icon: model.icon,
            isArchived: model.isArchived,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            statementDayOfMonth: model.statementDayOfMonth,
            dueDayOfMonth: model.dueDayOfMonth
        )
    }

    nonisolated static func updateModel(_ model: SDAccount, from entity: AccountEntity) {
        model.name = entity.name
        model.type = entity.type
        model.balance = entity.balance
        model.openingBalance = entity.openingBalance
        model.currencyCode = entity.currencyCode
        model.icon = entity.icon
        model.isArchived = entity.isArchived
        model.statementDayOfMonth = entity.statementDayOfMonth
        model.dueDayOfMonth = entity.dueDayOfMonth
        model.updatedAt = .now
    }
}
