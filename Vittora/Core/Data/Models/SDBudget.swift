import Foundation
import SwiftData

@Model
final class SDBudget {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var spent: Decimal = 0
    var periodRawValue: String = BudgetPeriod.monthly.rawValue
    var startDate: Date = Date.now
    var rollover: Bool = false
    var categoryID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        amount: Decimal,
        spent: Decimal = 0,
        period: BudgetPeriod = .monthly,
        startDate: Date = .now,
        rollover: Bool = false,
        categoryID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.spent = spent
        self.periodRawValue = period.rawValue
        self.startDate = startDate
        self.rollover = rollover
        self.categoryID = categoryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRawValue) ?? .monthly }
        set { periodRawValue = newValue.rawValue }
    }

    var remaining: Decimal { amount - spent }

    var progress: Double {
        guard amount > 0 else { return 0 }
        return min(Double(truncating: (spent / amount) as NSDecimalNumber), 2.0)
    }

    var isOverBudget: Bool { spent > amount }
}
