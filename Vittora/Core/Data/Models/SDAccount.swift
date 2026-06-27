import Foundation
import SwiftData

@Model
final class SDAccount {
    #Index<SDAccount>([\.typeRawValue], [\.isArchived])

    var id: UUID = UUID()
    var name: String = ""
    var typeRawValue: String = AccountType.bank.rawValue
    var balance: Decimal = 0
    /// Balance before any transaction was applied (Schema V3, DATAINTEGRITY-12).
    /// Optional for CloudKit additive compatibility: `nil` on pre-V3 rows, where
    /// reconciliation derives the implied opening (`balance − Σ effects`) on read
    /// instead of pinning a possibly-unsynced baseline.
    var openingBalance: Decimal?
    var currencyCode: String = CurrencyDefaults.code
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
        openingBalance: Decimal? = nil,
        currencyCode: String = CurrencyDefaults.code,
        icon: String = "building.columns.fill",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
        self.balance = balance
        self.openingBalance = openingBalance
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
