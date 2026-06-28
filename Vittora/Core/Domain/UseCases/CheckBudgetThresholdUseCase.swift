import Foundation

/// Spending milestones that trigger budget alert notifications (FUNCTIONAL-2 / C3).
enum BudgetThresholdLevel: Int, CaseIterable, Sendable, Comparable {
    case fifty = 50
    case seventyFive = 75
    case ninety = 90
    case hundred = 100

    var progressMinimum: Double {
        Double(rawValue) / 100.0
    }

    static func < (lhs: BudgetThresholdLevel, rhs: BudgetThresholdLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CheckBudgetThresholdUseCase: Sendable {
    /// Return budgets that are at 50% or above.
    func execute(budgets: [BudgetEntity]) -> [BudgetEntity] {
        budgets.filter { $0.progress >= BudgetThresholdLevel.fifty.progressMinimum }
    }

    /// Threshold levels newly reached for this budget that were not previously fired.
    func newlyCrossedThresholds(
        for budget: BudgetEntity,
        previouslyFired: Set<BudgetThresholdLevel>
    ) -> [BudgetThresholdLevel] {
        BudgetThresholdLevel.allCases.filter { level in
            budget.progress >= level.progressMinimum && !previouslyFired.contains(level)
        }
    }
}
