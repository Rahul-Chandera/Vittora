import Foundation
import SwiftData

extension VittoraSchemaV1 {
    /// Frozen debt shape for Schemas V1–V4: single legacy `linkedTransactionID`
    /// only — `linkedTransactionIDsJSON` was added in V5.
    @Model
    public final class SDDebt {
        #Index<SDDebt>([\.payeeID], [\.isSettled])

        public var id: UUID = UUID()
        public var payeeID: UUID = UUID()
        public var amount: Decimal = Decimal(0)
        public var settledAmount: Decimal = Decimal(0)
        public var directionRawValue: String = DebtDirection.lent.rawValue
        public var dueDate: Date? = nil
        public var note: String? = nil
        public var isSettled: Bool = false
        public var linkedTransactionID: UUID? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public init() {}

        public init(
            id: UUID = UUID(),
            payeeID: UUID,
            amount: Decimal,
            direction: DebtDirection
        ) {
            self.id = id
            self.payeeID = payeeID
            self.amount = amount
            self.directionRawValue = direction.rawValue
        }
    }
}
