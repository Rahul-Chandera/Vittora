import Foundation
import SwiftData

struct DatabaseStats: Sendable {
    let transactionCount: Int
    let accountCount: Int
    let categoryCount: Int
    let budgetCount: Int
    let debtCount: Int
    let savingsGoalCount: Int
    let splitGroupCount: Int
    let documentCount: Int

    var totalRecords: Int {
        transactionCount + accountCount + categoryCount + budgetCount +
        debtCount + savingsGoalCount + splitGroupCount + documentCount
    }
}

enum ClearDataScope: CaseIterable, Sendable {
    case transactions
    case budgets
    case debts
    case savingsGoals
    case splits
    case all

    var displayName: String {
        switch self {
        case .transactions:  return String(localized: "Transactions")
        case .budgets:       return String(localized: "Budgets")
        case .debts:         return String(localized: "Debts")
        case .savingsGoals:  return String(localized: "Savings Goals")
        case .splits:        return String(localized: "Split Groups")
        case .all:           return String(localized: "Everything")
        }
    }
}

@MainActor
final class DataManagementService: Sendable {
    private let transactionRepository: any TransactionRepository
    private let accountRepository: any AccountRepository
    private let categoryRepository: any CategoryRepository
    private let budgetRepository: any BudgetRepository
    private let debtRepository: any DebtRepository
    private let savingsGoalRepository: any SavingsGoalRepository
    private let splitGroupRepository: any SplitGroupRepository
    private let documentRepository: any DocumentRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        budgetRepository: any BudgetRepository,
        debtRepository: any DebtRepository,
        savingsGoalRepository: any SavingsGoalRepository,
        splitGroupRepository: any SplitGroupRepository,
        documentRepository: any DocumentRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.budgetRepository = budgetRepository
        self.debtRepository = debtRepository
        self.savingsGoalRepository = savingsGoalRepository
        self.splitGroupRepository = splitGroupRepository
        self.documentRepository = documentRepository
    }

    // MARK: - Statistics

    func fetchStats() async throws -> DatabaseStats {
        async let transactions = transactionRepository.fetchAll(filter: nil)
        async let accounts     = accountRepository.fetchAll()
        async let categories   = categoryRepository.fetchAll()
        async let budgets      = budgetRepository.fetchAll()
        async let debts        = debtRepository.fetchAll()
        async let goals        = savingsGoalRepository.fetchAll()
        async let groups       = splitGroupRepository.fetchAllGroups()
        async let documents    = documentRepository.fetchAll()

        return try await DatabaseStats(
            transactionCount: transactions.count,
            accountCount:     accounts.count,
            categoryCount:    categories.count,
            budgetCount:      budgets.count,
            debtCount:        debts.count,
            savingsGoalCount: goals.count,
            splitGroupCount:  groups.count,
            documentCount:    documents.count
        )
    }

    // MARK: - Clear data

    func clearData(scope: ClearDataScope) async throws {
        switch scope {
        case .transactions:
            try await deleteAll(from: transactionRepository)
        case .budgets:
            try await deleteAll(from: budgetRepository)
        case .debts:
            try await deleteAll(from: debtRepository)
        case .savingsGoals:
            try await deleteAll(from: savingsGoalRepository)
        case .splits:
            let groups = try await splitGroupRepository.fetchAllGroups()
            for group in groups {
                try await splitGroupRepository.deleteGroup(group.id)
            }
        case .all:
            try await deleteAll(from: transactionRepository)
            try await deleteAll(from: budgetRepository)
            try await deleteAll(from: debtRepository)
            try await deleteAll(from: savingsGoalRepository)
            let groups = try await splitGroupRepository.fetchAllGroups()
            for group in groups {
                try await splitGroupRepository.deleteGroup(group.id)
            }
            // Keep accounts and categories — user likely wants to preserve structure
        }
    }

    func factoryReset() async throws {
        try await clearData(scope: .all)
        let accounts = try await accountRepository.fetchAll()
        for account in accounts { try await accountRepository.delete(account.id) }
        let categories = try await categoryRepository.fetchAll()
        for category in categories { try await categoryRepository.delete(category.id) }
        UserDefaults.standard.removeObject(forKey: "vittora.onboardingComplete")
        UserDefaults.standard.removeObject(forKey: "vittora.lastSyncDate")
    }

    // MARK: - Helpers

    private func deleteAll(from repo: any TransactionRepository) async throws {
        let items = try await repo.fetchAll(filter: nil)
        for item in items { try await repo.delete(item.id) }
    }

    private func deleteAll(from repo: any BudgetRepository) async throws {
        let items = try await repo.fetchAll()
        for item in items { try await repo.delete(item.id) }
    }

    private func deleteAll(from repo: any DebtRepository) async throws {
        let items = try await repo.fetchAll()
        for item in items { try await repo.delete(item.id) }
    }

    private func deleteAll(from repo: any SavingsGoalRepository) async throws {
        let items = try await repo.fetchAll()
        for item in items { try await repo.delete(item.id) }
    }
}
