import Foundation
import SwiftData

@Model
public final class SDPayee {
    #Index<SDPayee>([\.typeRawValue])

    public var id: UUID = UUID()
    public var name: String = ""
    public var typeRawValue: String = PayeeType.business.rawValue
    public var phone: String?
    public var email: String?
    public var notes: String?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
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

    public var type: PayeeType {
        get { PayeeType(rawValue: typeRawValue) ?? .business }
        set { typeRawValue = newValue.rawValue }
    }
}
