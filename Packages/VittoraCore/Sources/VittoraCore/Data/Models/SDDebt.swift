import Foundation
import OSLog
import SwiftData

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
    /// JSON-encoded `[UUID]` of cash legs from each settlement (Schema V5, A11).
    /// Stored as String for CloudKit compatibility (same pattern as `SDSplitGroup.memberIDsJSON`).
    public var linkedTransactionIDsJSON: String = "[]"
    /// Legacy single link from pre-V5 rows (DATAINTEGRITY-7). Read-side only —
    /// `DebtMapper` merges into `linkedTransactionIDs`; new writes use the JSON array.
    public var linkedTransactionID: UUID? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    public init() {}

    public init(
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
        self.linkedTransactionIDsJSON = Self.encode(linkedTransactionIDs)
        self.linkedTransactionID = linkedTransactionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRawValue) ?? .lent }
        set { directionRawValue = newValue.rawValue }
    }

    public var linkedTransactionIDs: [UUID] {
        get { Self.decode(linkedTransactionIDsJSON) }
        set { linkedTransactionIDsJSON = Self.encode(newValue) }
    }

    private static func encode(_ ids: [UUID]) -> String {
        do {
            let data = try JSONEncoder().encode(ids)
            guard let str = String(data: data, encoding: .utf8) else {
                logger.error("Failed to encode debt linked transaction IDs as UTF-8.")
                return "[]"
            }
            return str
        } catch {
            logger.error("Failed to encode debt linked transaction IDs: \(error.localizedDescription, privacy: .public)")
            return "[]"
        }
    }

    private static func decode(_ json: String) -> [UUID] {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to decode debt linked transaction IDs JSON as UTF-8.")
            return []
        }

        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            logger.error("Failed to decode debt linked transaction IDs: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
