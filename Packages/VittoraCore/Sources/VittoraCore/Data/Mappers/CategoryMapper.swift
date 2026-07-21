import Foundation
import SwiftData

public enum CategoryMapper {
    public nonisolated static func toEntity(_ model: SDCategory) -> CategoryEntity {
        CategoryEntity(
            id: model.id,
            name: model.name,
            icon: model.icon,
            colorHex: model.colorHex,
            type: model.type,
            spendingBucket: model.spendingBucket,
            isDefault: model.isDefault,
            sortOrder: model.sortOrder,
            parentID: model.parentID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public nonisolated static func updateModel(_ model: SDCategory, from entity: CategoryEntity) {
        model.name = entity.name
        model.icon = entity.icon
        model.colorHex = entity.colorHex
        model.type = entity.type
        model.spendingBucket = entity.spendingBucket
        model.isDefault = entity.isDefault
        model.sortOrder = entity.sortOrder
        model.parentID = entity.parentID
        model.updatedAt = .now
    }
}
