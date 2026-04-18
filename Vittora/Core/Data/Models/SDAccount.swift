import Foundation
import SwiftData

@Model
final class SDAccount {
    #Index<SDAccount>([\.typeRawValue], [\.isArchived])

    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var typeRawValue: String = AccountType.bank.rawValue
    var balance: Decimal = 0
    var currencyCode: String = "USD"
    var icon: String = "building.columns.fill"
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        currencyCode: String = "USD",
        icon: String = "building.columns.fill",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
        self.balance = balance
        self.currencyCode = currencyCode
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .bank }
        set { typeRawValue = newValue.rawValue }
    }
}
