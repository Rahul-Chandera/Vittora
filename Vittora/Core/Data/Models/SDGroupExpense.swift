import Foundation
import SwiftData

@Model
final class SDGroupExpense {
    #Index<SDGroupExpense>([\.groupID], [\.date], [\.isSettled])

    @Attribute(.unique) var id: UUID = UUID()
    var groupID: UUID = UUID()
    var paidByMemberID: UUID = UUID()
    var amount: Decimal = Decimal(0)
    var title: String = ""
    var date: Date = Date.now
    /// Raw value of SplitMethod enum
    var splitMethodRawValue: String = SplitMethod.equal.rawValue
    /// JSON-encoded [SplitShare]
    var sharesJSON: String = "[]"
    var categoryID: UUID? = nil
    var note: String? = nil
    var isSettled: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
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

    var splitMethod: SplitMethod {
        get { SplitMethod(rawValue: splitMethodRawValue) ?? .equal }
        set { splitMethodRawValue = newValue.rawValue }
    }

    var shares: [SplitShare] {
        get { SDGroupExpense.decode(sharesJSON) }
        set { sharesJSON = SDGroupExpense.encode(newValue) }
    }

    private static func encode(_ shares: [SplitShare]) -> String {
        guard let data = try? JSONEncoder().encode(shares),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func decode(_ json: String) -> [SplitShare] {
        guard let data = json.data(using: .utf8),
              let shares = try? JSONDecoder().decode([SplitShare].self, from: data) else { return [] }
        return shares
    }
}
