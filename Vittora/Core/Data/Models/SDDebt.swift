import Foundation
import SwiftData

@Model
final class SDDebt {
    #Index<SDDebt>([\.payeeID], [\.isSettled])

    var id: UUID = UUID()
    var payeeID: UUID = UUID()
    var amount: Decimal = Decimal(0)
    var settledAmount: Decimal = Decimal(0)
    var directionRawValue: String = DebtDirection.lent.rawValue
    var dueDate: Date? = nil
    var note: String? = nil
    var isSettled: Bool = false
    /// Cash legs from each settlement (Schema V5, A11). Append-only at write time.
    var linkedTransactionIDs: [UUID] = []
    /// Legacy single link from pre-V5 rows (DATAINTEGRITY-7). Read-side only —
    /// `DebtMapper` merges into `linkedTransactionIDs`; new writes use the array.
    var linkedTransactionID: UUID? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        payeeID: UUID,
        amount: Decimal,
        settledAmount: Decimal = 0,
        direction: DebtDirection,
        dueDate: Date? = nil,
        note: String? = nil,
        isSettled: Bool = false,
        linkedTransactionIDs: [UUID] = [],
        linkedTransactionID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.payeeID = payeeID
        self.amount = amount
        self.settledAmount = settledAmount
        self.directionRawValue = direction.rawValue
        self.dueDate = dueDate
        self.note = note
        self.isSettled = isSettled
        self.linkedTransactionIDs = linkedTransactionIDs
        self.linkedTransactionID = linkedTransactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRawValue) ?? .lent }
        set { directionRawValue = newValue.rawValue }
    }
}
