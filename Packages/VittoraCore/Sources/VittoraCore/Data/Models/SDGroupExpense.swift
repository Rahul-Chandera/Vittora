import Foundation
import OSLog
import SwiftData

@Model
public final class SDGroupExpense {
    #Index<SDGroupExpense>([\.groupID], [\.date], [\.isSettled])

    public var id: UUID = UUID()
    public var groupID: UUID = UUID()
    public var paidByMemberID: UUID = UUID()
    public var amount: Decimal = Decimal(0)
    public var title: String = ""
    public var date: Date = Date.now
    /// Raw value of SplitMethod enum
    public var splitMethodRawValue: String = SplitMethod.equal.rawValue
    /// JSON-encoded [SplitShare]
    public var sharesJSON: String = "[]"
    public var categoryID: UUID? = nil
    public var note: String? = nil
    public var isSettled: Bool = false
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    public init() {}

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        paidByMemberID: UUID,
        amount: Decimal,
        title: String,
        date: Date = .now,
        splitMethod: SplitMethod = .equal,
        shares: [SplitShare] = [],
        categoryID: UUID? = nil,
        note: String? = nil,
        isSettled: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.groupID = groupID
        self.paidByMemberID = paidByMemberID
        self.amount = amount
        self.title = title
        self.date = date
        self.splitMethodRawValue = splitMethod.rawValue
        self.sharesJSON = SDGroupExpense.encode(shares)
        self.categoryID = categoryID
        self.note = note
        self.isSettled = isSettled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var splitMethod: SplitMethod {
        get { SplitMethod(rawValue: splitMethodRawValue) ?? .equal }
        set { splitMethodRawValue = newValue.rawValue }
    }

    public var shares: [SplitShare] {
        get { SDGroupExpense.decode(sharesJSON) }
        set { sharesJSON = SDGroupExpense.encode(newValue) }
    }

    private static func encode(_ shares: [SplitShare]) -> String {
        do {
            let data = try JSONEncoder().encode(shares)
            guard let str = String(data: data, encoding: .utf8) else {
                logger.error("Failed to encode split shares as UTF-8.")
                return "[]"
            }
            return str
        } catch {
            logger.error("Failed to encode split shares: \(error.localizedDescription, privacy: .public)")
            return "[]"
        }
    }

    private static func decode(_ json: String) -> [SplitShare] {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to decode split shares JSON as UTF-8.")
            return []
        }

        do {
            return try JSONDecoder().decode([SplitShare].self, from: data)
        } catch {
            logger.error("Failed to decode split shares: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
