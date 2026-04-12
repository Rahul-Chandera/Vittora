import Foundation

enum BudgetPeriod: String, Sendable, Hashable, CaseIterable, Codable {
    case weekly, monthly, quarterly, yearly
}

struct BudgetEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var amount: Decimal
    var spent: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var rollover: Bool
    var categoryID: UUID?
    var createdAt: Date
    var updatedAt: Date

    var remaining: Decimal { amount - spent }

    var progress: Double {
        guard amount > 0 else { return 0 }
        return min(Double(truncating: (spent / amount) as NSDecimalNumber), 2.0)
    }

    var isOverBudget: Bool { spent > amount }

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
        self.period = period
        self.startDate = startDate
        self.rollover = rollover
        self.categoryID = categoryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
