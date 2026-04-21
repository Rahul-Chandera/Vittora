import Foundation
import SwiftData
import os

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

    private static let logger = Logger(subsystem: "com.vittora.app", category: "SyncIntegrity")

    func validateAmountBearingEntities() async -> [IntegrityViolation] {
        var violations: [IntegrityViolation] = []
        do { violations += try checkTransactions() } catch {
            Self.logger.error("SyncIntegrityValidator: transaction fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        do { violations += try checkBudgets() } catch {
            Self.logger.error("SyncIntegrityValidator: budget fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        do { violations += try checkDebts() } catch {
            Self.logger.error("SyncIntegrityValidator: debt fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        do { violations += try checkGroupExpenses() } catch {
            Self.logger.error("SyncIntegrityValidator: group expense fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        do { violations += try checkAccounts() } catch {
            Self.logger.error("SyncIntegrityValidator: account fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        return violations
    }

    // MARK: - Per-entity checks

    private func checkTransactions() throws -> [IntegrityViolation] {
        let all = try modelContext.fetch(FetchDescriptor<SDTransaction>())
        return all.compactMap { entity in
            if !entity.amount.isFiniteDecimal {
                return IntegrityViolation(
                    entityType: "Transaction",
                    entityID: entity.id,
                    description: "Transaction \(entity.id) has non-finite amount"
                )
            }
            guard entity.amount > 0, !entity.currencyCode.isEmpty, entity.currencyCode.count == 3 else {
                return IntegrityViolation(
                    entityType: "Transaction",
                    entityID: entity.id,
                    description: "Transaction \(entity.id) has amount \(entity.amount) or invalid currencyCode '\(entity.currencyCode)'"
                )
            }
            return nil
        }
    }

    private func checkAccounts() throws -> [IntegrityViolation] {
        let all = try modelContext.fetch(FetchDescriptor<SDAccount>())
        return all.compactMap { entity in
            if !entity.balance.isFiniteDecimal {
                return IntegrityViolation(
                    entityType: "Account",
                    entityID: entity.id,
                    description: "Account \(entity.id) has non-finite balance"
                )
            }
            guard !entity.currencyCode.isEmpty, entity.currencyCode.count == 3 else {
                return IntegrityViolation(
                    entityType: "Account",
                    entityID: entity.id,
                    description: "Account \(entity.id) has invalid currency code '\(entity.currencyCode)'"
                )
            }
            if entity.type.isAsset, entity.balance < 0 {
                return IntegrityViolation(
                    entityType: "Account",
                    entityID: entity.id,
                    description: "Asset account \(entity.id) has negative balance \(entity.balance)"
                )
            }
            return nil
        }
    }

    private func checkBudgets() throws -> [IntegrityViolation] {
        let all = try modelContext.fetch(FetchDescriptor<SDBudget>())
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

    private func checkDebts() throws -> [IntegrityViolation] {
        let all = try modelContext.fetch(FetchDescriptor<SDDebt>())
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

    private func checkGroupExpenses() throws -> [IntegrityViolation] {
        let all = try modelContext.fetch(FetchDescriptor<SDGroupExpense>())
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
