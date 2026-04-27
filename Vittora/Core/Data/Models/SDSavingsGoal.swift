import Foundation
import SwiftData

@Model
final class SDSavingsGoal {
    #Index<SDSavingsGoal>([\.statusRawValue], [\.linkedAccountID])

    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var categoryRawValue: String = GoalCategory.other.rawValue
    var targetAmount: Decimal = Decimal(0)
    var currentAmount: Decimal = Decimal(0)
    var targetDate: Date? = nil
    var linkedAccountID: UUID? = nil
    var note: String? = nil
    var statusRawValue: String = GoalStatus.active.rawValue
    var colorHex: String = "#5856D6"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
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

    var category: GoalCategory {
        get { GoalCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }
}
