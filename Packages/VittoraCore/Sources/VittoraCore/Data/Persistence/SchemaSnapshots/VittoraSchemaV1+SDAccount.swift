import Foundation
import SwiftData

extension VittoraSchemaV1 {
    /// Frozen account shape for Schemas V1–V3: no `openingBalance` (added in V4)
    /// and no statement/due days (added in V6). Snapshots must never alias the
    /// live model — aliasing made V3–V6 checksums identical and crashed staged
    /// migration with "Duplicate version checksums detected".
    @Model
    public final class SDAccount {
        #Index<SDAccount>([\.typeRawValue], [\.isArchived])

        public var id: UUID = UUID()
        public var name: String = ""
        public var typeRawValue: String = AccountType.bank.rawValue
        public var balance: Decimal = 0
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
            currencyCode: String = CurrencyDefaults.code
        ) {
            self.id = id
            self.name = name
            self.typeRawValue = type.rawValue
            self.balance = balance
            self.currencyCode = currencyCode
        }
    }
}
