import Foundation
import VittoraCore

struct SubscriptionCostSummary: Sendable {
    let monthlyCost: Decimal
    let annualCost: Decimal
    let ruleCount: Int
}

struct CalculateSubscriptionCostUseCase: Sendable {
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    nonisolated init(
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    /// `incomeCategoryIDs` is required, not defaulted. This figure is labelled
    /// "Monthly Spend", and the loop used to total every active rule regardless
    /// of direction — so a salary rule of 6,400 against rent 1,850 and
    /// subscriptions 15.49 reported 8,265.49 a month and 99,185.88 a year, on
    /// both the recurring list and the subscription tracker.
    ///
    /// A rule carries no transaction type of its own; direction lives on its
    /// category, so the caller has to resolve it. A default of `[]` would have
    /// let a call site keep the bug silently, which is how it reached two
    /// screens.
    ///
    /// A rule with no category counts as spend: it cannot be shown to be
    /// income, and this is a spending figure.
    func execute(
        rules: [RecurringRuleEntity],
        incomeCategoryIDs: Set<UUID>
    ) -> SubscriptionCostSummary {
        var totalMonthlyCost: Decimal = 0

        let spendRules = rules.filter { rule in
            guard rule.isActive else { return false }
            guard let categoryID = rule.templateCategoryID else { return true }
            return !incomeCategoryIDs.contains(categoryID)
        }

        for rule in spendRules {
            let monthlyEquivalent = monthlyEquivalent(
                amount: rule.templateAmount,
                frequency: rule.frequency
            )
            totalMonthlyCost += monthlyEquivalent
        }

        let annualCost = totalMonthlyCost * 12
        let ruleCount = spendRules.count

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
