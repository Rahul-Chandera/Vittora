import Foundation

/// Progress metrics for a budget.
struct BudgetProgress: Sendable {
    let budget: BudgetEntity
    let spent: Decimal
    let remaining: Decimal
    let percentage: Double  // 0.0 to 1.0+
    let daysRemaining: Int
    let projectedSpend: Decimal
    let statusColor: String  // "safe" / "warning" / "danger"
}

struct CalculateBudgetProgressUseCase: Sendable {
    /// Calculate comprehensive progress metrics for a budget.
    func execute(budget: BudgetEntity) -> BudgetProgress {
        let spent = budget.spent
        let remaining = budget.remaining
        let percentage = budget.progress
        let daysRemaining = calculateDaysRemaining(for: budget)
        let projectedSpend = calculateProjectedSpend(spent: spent, daysRemaining: daysRemaining, budget: budget)
        let statusColor = determineStatusColor(percentage: percentage)

        return BudgetProgress(
            budget: budget,
            spent: spent,
            remaining: remaining,
            percentage: percentage,
            daysRemaining: daysRemaining,
            projectedSpend: projectedSpend,
            statusColor: statusColor
        )
    }

    private func calculateDaysRemaining(for budget: BudgetEntity) -> Int {
        let calendar = Calendar.current
        let dateRange = budget.period.dateRange(startingFrom: budget.startDate)
        let now = Date()

        if now > dateRange.upperBound {
            return 0
        }

        let components = calendar.dateComponents([.day], from: now, to: dateRange.upperBound)
        return max(0, components.day ?? 0)
    }

    private func calculateProjectedSpend(spent: Decimal, daysRemaining: Int, budget: BudgetEntity) -> Decimal {
        guard daysRemaining > 0 else { return spent }

        let dateRange = budget.period.dateRange(startingFrom: budget.startDate)
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 1
        let daysPassed = max(1, totalDays - daysRemaining)

        guard daysPassed > 0 else { return spent }

        let dailyRate = spent / Decimal(daysPassed)
        return spent + (dailyRate * Decimal(daysRemaining))
    }

    private func determineStatusColor(percentage: Double) -> String {
        if percentage >= 0.9 {
            return "danger"
        } else if percentage >= 0.75 {
            return "warning"
        } else {
            return "safe"
        }
    }
}
