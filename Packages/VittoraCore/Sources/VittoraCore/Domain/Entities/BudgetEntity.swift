import Foundation

public enum BudgetPeriod: String, Sendable, Hashable, CaseIterable, Codable {
    case weekly, monthly, quarterly, yearly

    public var displayName: String {
        switch self {
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .quarterly: String(localized: "Quarterly")
        case .yearly: String(localized: "Yearly")
        }
    }

    public nonisolated func dateRange(startingFrom startDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let endDate: Date
        switch self {
        case .weekly:
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case .monthly:
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .quarterly:
            endDate = calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .yearly:
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
        return startDate...endDate
    }
}

public struct BudgetEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var amount: Decimal
    public nonisolated var spent: Decimal
    public nonisolated var period: BudgetPeriod
    public nonisolated var startDate: Date
    public nonisolated var rollover: Bool
    public nonisolated var categoryID: UUID?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public var remaining: Decimal { amount - spent }

    public var progress: Double {
        guard amount > 0 else { return 0 }
        return min(Double(truncating: (spent / amount) as NSDecimalNumber), 2.0)
    }

    public var isOverBudget: Bool { spent > amount }

    public nonisolated init(
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

    // MARK: - Equatable & Hashable (identity-based)

    public static func == (lhs: BudgetEntity, rhs: BudgetEntity) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
