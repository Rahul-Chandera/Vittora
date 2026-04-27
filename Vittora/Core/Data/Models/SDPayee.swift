import Foundation
import SwiftData

@Model
final class SDPayee {
    #Index<SDPayee>([\.typeRawValue])

    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var typeRawValue: String = PayeeType.business.rawValue
    var phone: String?
    var email: String?
    var notes: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        name: String,
        type: PayeeType = .business,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
        self.phone = phone
        self.email = email
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: PayeeType {
        get { PayeeType(rawValue: typeRawValue) ?? .business }
        set { typeRawValue = newValue.rawValue }
    }
}
