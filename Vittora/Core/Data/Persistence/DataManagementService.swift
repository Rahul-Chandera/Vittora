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
    private let payeeRepository: (any PayeeRepository)?
    private let recurringRuleRepository: (any RecurringRuleRepository)?
    private let taxProfileRepository: (any TaxProfileRepository)?
    private let documentStorageService: (any DocumentStorageServiceProtocol)?
    private let keychainService: any KeychainServiceProtocol

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        budgetRepository: any BudgetRepository,
        debtRepository: any DebtRepository,
        savingsGoalRepository: any SavingsGoalRepository,
        splitGroupRepository: any SplitGroupRepository,
        documentRepository: any DocumentRepository,
        payeeRepository: (any PayeeRepository)? = nil,
        recurringRuleRepository: (any RecurringRuleRepository)? = nil,
        taxProfileRepository: (any TaxProfileRepository)? = nil,
        documentStorageService: (any DocumentStorageServiceProtocol)? = nil,
        keychainService: (any KeychainServiceProtocol)? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.budgetRepository = budgetRepository
        self.debtRepository = debtRepository
        self.savingsGoalRepository = savingsGoalRepository
        self.splitGroupRepository = splitGroupRepository
        self.documentRepository = documentRepository
        self.payeeRepository = payeeRepository
        self.recurringRuleRepository = recurringRuleRepository
        self.taxProfileRepository = taxProfileRepository
        self.documentStorageService = documentStorageService
        self.keychainService = keychainService ?? KeychainService()
    }

    // MARK: - Statistics

    func fetchStats() async throws -> DatabaseStats {
        async let transactionCount = transactionRepository.fetchTransactionCount()
        async let accounts     = accountRepository.fetchAll()
        async let categories   = categoryRepository.fetchAll()
        async let budgets      = budgetRepository.fetchAll()
        async let debts        = debtRepository.fetchAll()
        async let goals        = savingsGoalRepository.fetchAll()
        async let groups       = splitGroupRepository.fetchAllGroups()
        async let documentCount = documentRepository.fetchCount()

        return try await DatabaseStats(
            transactionCount: transactionCount,
            accountCount:     accounts.count,
            categoryCount:    categories.count,
            budgetCount:      budgets.count,
            debtCount:        debts.count,
            savingsGoalCount: goals.count,
            splitGroupCount:  groups.count,
            documentCount:    documentCount
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
            try await deleteAllDocuments()
            if let payeeRepository {
                try await deleteAll(from: payeeRepository)
            }
            if let recurringRuleRepository {
                try await deleteAll(from: recurringRuleRepository)
            }
            if let taxProfileRepository {
                try await taxProfileRepository.delete()
            }
            // Keep accounts and categories in clear-all mode for structural retention.
        }
    }

    func factoryReset() async throws {
        try await clearData(scope: .all)
        let accounts = try await accountRepository.fetchAll()
        for account in accounts { try await accountRepository.delete(account.id) }
        let categories = try await categoryRepository.fetchAll()
        for category in categories { try await categoryRepository.delete(category.id) }

        // Clear sensitive Keychain entries
        try await keychainService.delete(forKey: "vittora.onboardingComplete")
        try await keychainService.delete(forKey: "vittora.appLockEnabled")
        try await keychainService.delete(forKey: "vittora.passcodeFallback")
        try await keychainService.delete(forKey: "vittora.userName")
        try await keychainService.delete(forKey: "com.vittora.encryption.key")
        try await keychainService.delete(forKey: "com.vittora.encryption.key.se_wrapped")

        UserDefaults.standard.removeObject(forKey: "vittora.lastSyncDate")
        AppUserDefaults.sync.removeObject(forKey: "vittora.lastSyncDate")
    }

    // MARK: - Helpers

    private func deleteAll(from repo: any TransactionRepository) async throws {
        while true {
            let items = try await repo.fetchAll(filter: nil)
            if items.isEmpty { break }
            for item in items { try await repo.delete(item.id) }
        }
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

    private func deleteAll(from repo: any PayeeRepository) async throws {
        let items = try await repo.fetchAll()
        for item in items { try await repo.delete(item.id) }
    }

    private func deleteAll(from repo: any RecurringRuleRepository) async throws {
        let items = try await repo.fetchAll()
        for item in items { try await repo.delete(item.id) }
    }

    private func deleteAllDocuments() async throws {
        let documents = try await documentRepository.fetchAll()
        if let documentStorageService {
            let deleteUseCase = DeleteDocumentUseCase(
                documentRepository: documentRepository,
                documentStorageService: documentStorageService
            )
            for document in documents {
                try await deleteUseCase.execute(id: document.id)
            }
        } else {
            for document in documents {
                try await documentRepository.delete(document.id)
            }
        }
    }
}
