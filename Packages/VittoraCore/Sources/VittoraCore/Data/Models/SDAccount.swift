import Foundation
import SwiftData

@Model
public final class SDAccount {
    #Index<SDAccount>([\.typeRawValue], [\.isArchived])

    public var id: UUID = UUID()
    public var name: String = ""
    public var typeRawValue: String = AccountType.bank.rawValue
    public var balance: Decimal = 0
    /// Balance before any transaction was applied (Schema V3, DATAINTEGRITY-12).
    /// Optional for CloudKit additive compatibility: `nil` on pre-V3 rows, where
    /// reconciliation derives the implied opening (`balance − Σ effects`) on read
    /// instead of pinning a possibly-unsynced baseline.
    public var openingBalance: Decimal?
    public var currencyCode: String = CurrencyDefaults.code
    public var icon: String = "building.columns.fill"
    public var isArchived: Bool = false
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    /// Statement closing day of month (1–31). Optional; credit cards only (C4).
    public var statementDayOfMonth: Int?
    /// Payment due day of month (1–31). Optional; credit cards only (C4).
    public var dueDayOfMonth: Int?

    public init() {}

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        openingBalance: Decimal? = nil,
        currencyCode: String = CurrencyDefaults.code,
        icon: String = "building.columns.fill",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        statementDayOfMonth: Int? = nil,
        dueDayOfMonth: Int? = nil
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
        self.statementDayOfMonth = statementDayOfMonth
        self.dueDayOfMonth = dueDayOfMonth
    }

    public var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .bank }
        set { typeRawValue = newValue.rawValue }
    }
}
