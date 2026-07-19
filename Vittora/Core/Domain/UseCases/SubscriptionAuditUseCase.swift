import Foundation
import VittoraCore

struct SubscriptionAuditRow: Identifiable, Sendable, Equatable {
    nonisolated var id: UUID { ruleID }
    nonisolated let ruleID: UUID
    nonisolated let name: String
    nonisolated let categoryName: String
    nonisolated let frequency: RecurrenceFrequency
    nonisolated let amount: Decimal
    nonisolated let monthlyCost: Decimal
    nonisolated let annualCost: Decimal
    nonisolated let lastRan: Date?
}

struct SubscriptionAuditReport: Sendable, Equatable {
    nonisolated let rows: [SubscriptionAuditRow]
    nonisolated let monthlyTotal: Decimal
    nonisolated let annualTotal: Decimal

    nonisolated var ruleCount: Int { rows.count }
}

struct SubscriptionAuditUseCase: Sendable {
    private let recurringRuleRepository: any RecurringRuleRepository
    private let categoryRepository: any CategoryRepository
    private let transactionRepository: any TransactionRepository
    private let nowProvider: @Sendable () -> Date

    nonisolated init(
        recurringRuleRepository: any RecurringRuleRepository,
        categoryRepository: any CategoryRepository,
        transactionRepository: any TransactionRepository,
        nowProvider: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.recurringRuleRepository = recurringRuleRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.nowProvider = nowProvider
    }

    func execute() async throws -> SubscriptionAuditReport {
        let now = nowProvider()
        let rules = try await recurringRuleRepository.fetchActive()
        let categories = try await categoryRepository.fetchAll()
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let expenseRules = rules.filter { rule in
            guard rule.isActive else { return false }
            if let endDate = rule.endDate, endDate < now { return false }
            guard let categoryID = rule.templateCategoryID else {
                // Uncategorized recurring rules post as expenses today.
                return true
            }
            guard let category = categoryByID[categoryID] else { return true }
            return category.type == .expense
        }

        var lastRanByRule: [UUID: Date] = [:]
        for rule in expenseRules {
            let linked = try await transactionRepository.fetchForRecurringRule(rule.id)
            if let latest = linked.map(\.date).max() {
                lastRanByRule[rule.id] = latest
            }
        }

        let rows: [SubscriptionAuditRow] = expenseRules.map { rule in
            let category = rule.templateCategoryID.flatMap { categoryByID[$0] }
            let categoryName = category?.name ?? String(localized: "Uncategorized")
            let name: String = {
                if let note = rule.templateNote?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !note.isEmpty {
                    return note
                }
                return categoryName
            }()
            let annualCost = SubscriptionCostNormalization.annualEquivalent(
                amount: rule.templateAmount,
                frequency: rule.frequency
            )
            let monthlyCost = SubscriptionCostNormalization.monthlyEquivalent(
                amount: rule.templateAmount,
                frequency: rule.frequency
            )
            return SubscriptionAuditRow(
                ruleID: rule.id,
                name: name,
                categoryName: categoryName,
                frequency: rule.frequency,
                amount: rule.templateAmount,
                monthlyCost: monthlyCost,
                annualCost: annualCost,
                lastRan: lastRanByRule[rule.id]
            )
        }
        .sorted { lhs, rhs in
            if lhs.monthlyCost == rhs.monthlyCost {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.monthlyCost > rhs.monthlyCost
        }

        // Sum columns independently — Decimal ÷12 then ×12 does not round-trip.
        let monthlyTotal = rows.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        let annualTotal = rows.reduce(Decimal(0)) { $0 + $1.annualCost }
        return SubscriptionAuditReport(
            rows: rows,
            monthlyTotal: monthlyTotal,
            annualTotal: annualTotal
        )
    }
}
