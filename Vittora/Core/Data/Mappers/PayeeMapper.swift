import Foundation
import SwiftData

enum PayeeMapper {
    static func toEntity(_ model: SDPayee) -> PayeeEntity {
        PayeeEntity(
            id: model.id,
            name: model.name,
            type: model.type,
            phone: model.phone,
            email: model.email,
            notes: model.notes,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func updateModel(_ model: SDPayee, from entity: PayeeEntity) {
        model.name = entity.name
        model.type = entity.type
        model.phone = entity.phone
        model.email = entity.email
        model.notes = entity.notes
        model.updatedAt = .now
    }
}
