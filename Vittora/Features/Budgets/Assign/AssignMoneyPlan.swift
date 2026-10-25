import Foundation
import VittoraCore

/// Zero-based budgeting on top of ordinary monthly budgets: this month's income, what
/// has been assigned to categories, and what is still waiting for a job.
///
/// An "assignment" is the category's monthly budget, so nothing new is stored and the
/// Budgets screen, alerts and reports all see the same numbers. Assigning turns
/// rollover on: unspent money carries into next month, as people switching from
/// envelope budgeting expect.
struct AssignMoneyPlan: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let categoryID: UUID
        let name: String
        let icon: String
        /// The monthly budget, or 0 when the category has none.
        let assigned: Decimal
        let spent: Decimal
        /// Set when the category's budget runs on another period, which this screen
        /// leaves alone; the Budgets screen edits it.
        let otherPeriod: BudgetPeriod?
        var available: Decimal { assigned - spent }
        var id: UUID { categoryID }
    }

    let income: Decimal
    let rows: [Row]
    var assigned: Decimal { rows.reduce(Decimal(0)) { $0 + $1.assigned } }
    var readyToAssign: Decimal { income - assigned }
}

enum AssignMoneyPlanner {
    /// - Parameters:
    ///   - transactions: this month's transactions, already in the main currency.
    ///   - budgets: the active budgets.
    static func plan(
        transactions: [TransactionEntity],
        budgets: [BudgetEntity],
        categories: [CategoryEntity]
    ) -> AssignMoneyPlan {
        let parentOf = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.parentID) })
        func topLevel(_ id: UUID?) -> UUID? {
            guard let id else { return nil }
            return parentOf[id].flatMap { $0 } ?? id
        }
        var spent: [UUID: Decimal] = [:]
        var income = Decimal(0)
        for transaction in transactions {
            switch transaction.type {
            case .income: income += transaction.amount
            case .expense:
                if let category = topLevel(transaction.categoryID) { spent[category, default: 0] += transaction.amount }
            default: break
            }
        }
        let budgetByCategory = Dictionary(
            budgets.compactMap { budget in budget.categoryID.map { ($0, budget) } },
            uniquingKeysWith: { first, _ in first }
        )
        let rows = categories
            .filter { $0.type == .expense && $0.parentID == nil }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            .map { category -> AssignMoneyPlan.Row in
                let budget = budgetByCategory[category.id]
                let monthly = budget?.period == .monthly ? budget : nil
                return AssignMoneyPlan.Row(
                    categoryID: category.id,
                    name: category.displayName,
                    icon: category.icon,
                    assigned: monthly?.amount ?? 0,
                    spent: spent[category.id] ?? 0,
                    otherPeriod: budget.flatMap { $0.period == .monthly ? nil : $0.period }
                )
            }
        return AssignMoneyPlan(income: income, rows: rows)
    }
}
