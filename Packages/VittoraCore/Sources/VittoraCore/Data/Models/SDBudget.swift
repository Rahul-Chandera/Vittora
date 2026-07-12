import Foundation
import SwiftData

@Model
public final class SDBudget {
    #Index<SDBudget>([\.categoryID], [\.startDate])

    public var id: UUID = UUID()
    public var amount: Decimal = 0
    public var spent: Decimal = 0
    public var periodRawValue: String = BudgetPeriod.monthly.rawValue
    public var startDate: Date = Date.now
    public var rollover: Bool = false
    public var categoryID: UUID?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
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

    public var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRawValue) ?? .monthly }
        set { periodRawValue = newValue.rawValue }
    }

    public var remaining: Decimal { amount - spent }

    public var progress: Double {
        guard amount > 0 else { return 0 }
        return min(Double(truncating: (spent / amount) as NSDecimalNumber), 2.0)
    }

    public var isOverBudget: Bool { spent > amount }
}
