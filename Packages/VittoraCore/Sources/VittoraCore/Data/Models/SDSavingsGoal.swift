import Foundation
import SwiftData

@Model
public final class SDSavingsGoal {
    #Index<SDSavingsGoal>([\.statusRawValue], [\.linkedAccountID])

    public var id: UUID = UUID()
    public var name: String = ""
    public var categoryRawValue: String = GoalCategory.other.rawValue
    public var targetAmount: Decimal = Decimal(0)
    public var currentAmount: Decimal = Decimal(0)
    public var targetDate: Date? = nil
    public var linkedAccountID: UUID? = nil
    public var note: String? = nil
    public var statusRawValue: String = GoalStatus.active.rawValue
    public var colorHex: String = "#5856D6"
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
        id: UUID = UUID(),
        name: String,
        category: GoalCategory,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        linkedAccountID: UUID? = nil,
        note: String? = nil,
        status: GoalStatus = .active,
        colorHex: String = "#5856D6",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.categoryRawValue = category.rawValue
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.linkedAccountID = linkedAccountID
        self.note = note
        self.statusRawValue = status.rawValue
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var category: GoalCategory {
        get { GoalCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    public var status: GoalStatus {
        get { GoalStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }
}
