import Foundation

struct SubscriptionCostSummary: Sendable {
    let monthlyCost: Decimal
    let annualCost: Decimal
    let ruleCount: Int
}

struct CalculateSubscriptionCostUseCase: Sendable {
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func execute(rules: [RecurringRuleEntity]) -> SubscriptionCostSummary {
        var totalMonthlyCost: Decimal = 0

        for rule in rules {
            guard rule.isActive else { continue }

            let monthlyEquivalent = monthlyEquivalent(
                amount: rule.templateAmount,
                frequency: rule.frequency
            )
            totalMonthlyCost += monthlyEquivalent
        }

        let annualCost = totalMonthlyCost * 12
        let ruleCount = rules.filter { $0.isActive }.count

        return SubscriptionCostSummary(
            monthlyCost: totalMonthlyCost,
            annualCost: annualCost,
            ruleCount: ruleCount
        )
    }

    /// Normalize a recurring amount to its monthly equivalent for the current calendar month.
    func monthlyEquivalent(amount: Decimal, frequency: RecurrenceFrequency) -> Decimal {
        let daysInMonth = Decimal(daysInReferenceMonth())

        switch frequency {
        case .daily:
            return amount * daysInMonth
        case .weekly:
            return amount * daysInMonth / 7
        case .biweekly:
            return amount * daysInMonth / 14
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .yearly:
            return amount / 12
        case .custom(let days):
            guard days > 0 else { return amount }
            return amount * daysInMonth / Decimal(days)
        }
    }

    private func daysInReferenceMonth() -> Int {
        calendar.range(of: .day, in: .month, for: nowProvider())?.count ?? 1
    }
}
