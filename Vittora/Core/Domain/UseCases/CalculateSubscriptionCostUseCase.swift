import Foundation

struct SubscriptionCostSummary: Sendable {
    let monthlyCost: Decimal
    let annualCost: Decimal
    let ruleCount: Int
}

struct CalculateSubscriptionCostUseCase: Sendable {
    init() {}

    func execute(rules: [RecurringRuleEntity]) -> SubscriptionCostSummary {
        var totalMonthlyCost: Decimal = 0

        for rule in rules {
            guard rule.isActive else { continue }

            let monthlyEquivalent = normalizeToMonthlyCost(
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

    /// Normalize a recurring amount to its monthly equivalent
    private func normalizeToMonthlyCost(amount: Decimal, frequency: RecurrenceFrequency) -> Decimal {
        switch frequency {
        case .daily:
            return amount * 30
        case .weekly:
            return amount * (Decimal(string: "4.33") ?? 4.33)
        case .biweekly:
            return amount * (Decimal(string: "2.165") ?? 2.165)
        case .monthly:
            return amount * 1
        case .quarterly:
            return amount / 3
        case .yearly:
            return amount / 12
        case .custom(let days):
            let daysPerMonth = Decimal(string: "30.0") ?? 30.0
            let daysFraction = Decimal(days) > 0 ? daysPerMonth / Decimal(days) : 1
            return amount * daysFraction
        }
    }
}
