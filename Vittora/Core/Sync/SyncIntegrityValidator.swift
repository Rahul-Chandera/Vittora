import Foundation
import SwiftData

struct IntegrityViolation: Sendable {
    let entityType: String
    let entityID: UUID?
    let description: String
}

protocol SyncIntegrityValidating: Sendable {
    func validateAmountBearingEntities() async -> [IntegrityViolation]
}

/// Scans amount-bearing SwiftData models for invariant violations after CloudKit imports.
/// Violations are returned as advisory notices; the system has already applied its own
/// last-writer-wins merge before this check runs.
@ModelActor
actor SyncIntegrityValidator: SyncIntegrityValidating {

    func validateAmountBearingEntities() async -> [IntegrityViolation] {
        var violations: [IntegrityViolation] = []
        violations += checkTransactions()
        violations += checkBudgets()
        violations += checkDebts()
        violations += checkGroupExpenses()
        return violations
    }

    // MARK: - Per-entity checks

    private func checkTransactions() -> [IntegrityViolation] {
        let all = (try? modelContext.fetch(FetchDescriptor<SDTransaction>())) ?? []
        return all.compactMap { entity in
            guard entity.amount > 0, !entity.currencyCode.isEmpty else {
                return IntegrityViolation(
                    entityType: "Transaction",
                    entityID: entity.id,
                    description: "Transaction \(entity.id) has amount \(entity.amount) or empty currencyCode '\(entity.currencyCode)'"
                )
            }
            return nil
        }
    }

    private func checkBudgets() -> [IntegrityViolation] {
        let all = (try? modelContext.fetch(FetchDescriptor<SDBudget>())) ?? []
        return all.compactMap { entity in
            guard entity.amount > 0 else {
                return IntegrityViolation(
                    entityType: "Budget",
                    entityID: entity.id,
                    description: "Budget \(entity.id) has non-positive limit amount \(entity.amount)"
                )
            }
            return nil
        }
    }

    private func checkDebts() -> [IntegrityViolation] {
        let all = (try? modelContext.fetch(FetchDescriptor<SDDebt>())) ?? []
        return all.compactMap { entity in
            guard entity.amount > 0, entity.settledAmount >= 0, entity.settledAmount <= entity.amount else {
                return IntegrityViolation(
                    entityType: "Debt",
                    entityID: entity.id,
                    description: "Debt \(entity.id) has amount \(entity.amount), settled \(entity.settledAmount)"
                )
            }
            return nil
        }
    }

    private func checkGroupExpenses() -> [IntegrityViolation] {
        let all = (try? modelContext.fetch(FetchDescriptor<SDGroupExpense>())) ?? []
        return all.compactMap { entity in
            guard entity.amount > 0 else {
                return IntegrityViolation(
                    entityType: "Group Expense",
                    entityID: entity.id,
                    description: "Group expense \(entity.id) has non-positive amount \(entity.amount)"
                )
            }
            return nil
        }
    }
}
