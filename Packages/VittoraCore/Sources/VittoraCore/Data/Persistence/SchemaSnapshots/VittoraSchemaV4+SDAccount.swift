import Foundation
import SwiftData

extension VittoraSchemaV4 {
    /// Frozen account shape for Schemas V4–V5: has `openingBalance`
    /// (added in V4) but not the statement/due days (added in V6).
    @Model
    public final class SDAccount {
        #Index<SDAccount>([\.typeRawValue], [\.isArchived])

        public var id: UUID = UUID()
        public var name: String = ""
        public var typeRawValue: String = AccountType.bank.rawValue
        public var balance: Decimal = 0
        public var openingBalance: Decimal?
        public var currencyCode: String = CurrencyDefaults.code
        public var icon: String = "building.columns.fill"
        public var isArchived: Bool = false
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public init() {}

        public init(
            id: UUID = UUID(),
            name: String,
            type: AccountType,
            balance: Decimal = 0,
            openingBalance: Decimal? = nil,
            currencyCode: String = CurrencyDefaults.code
        ) {
            self.id = id
            self.name = name
            self.typeRawValue = type.rawValue
            self.balance = balance
            self.openingBalance = openingBalance
            self.currencyCode = currencyCode
        }
    }
}
