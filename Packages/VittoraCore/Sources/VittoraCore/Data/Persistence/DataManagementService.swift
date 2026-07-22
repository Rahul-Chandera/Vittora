import Foundation
import SwiftData

public struct DatabaseStats: Sendable {
    public let transactionCount: Int
    public let accountCount: Int
    public let categoryCount: Int
    public let budgetCount: Int
    public let debtCount: Int
    public let savingsGoalCount: Int
    public let splitGroupCount: Int
    public let documentCount: Int

    public var totalRecords: Int {
        transactionCount + accountCount + categoryCount + budgetCount +
        debtCount + savingsGoalCount + splitGroupCount + documentCount
    }
}

public enum ClearDataScope: CaseIterable, Sendable {
    case transactions
    case budgets
    case debts
    case savingsGoals
    case splits
    case all

    public var displayName: String {
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
public final class DataManagementService: Sendable {
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
    private let dataSeeder: (any DataSeederProtocol)?

    public init(
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
        keychainService: any KeychainServiceProtocol,
        dataSeeder: (any DataSeederProtocol)? = nil
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
        self.keychainService = keychainService
        self.dataSeeder = dataSeeder
    }

    // MARK: - Statistics

    public func fetchStats() async throws -> DatabaseStats {
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

    public func clearData(scope: ClearDataScope) async throws {
        switch scope {
        case .transactions:
            try await deleteAll(from: transactionRepository)
            await clearSpotlightAfterTransactionDeletion()
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
            await clearSpotlightAfterTransactionDeletion()
        }
    }

    /// - Parameter alsoDestroyOnDiskStore: pass `true` in recovery mode, where
    ///   the repositories only clear the in-memory container and the unopenable
    ///   on-disk store must be deleted too or the next launch lands straight
    ///   back in recovery. Never pass `true` while an on-disk container is open.
    ///   ponytail: CloudKit server records are not purged; stale rows can
    ///   re-sync after a recovery reset and can be deleted normally then.
    public func factoryReset(alsoDestroyOnDiskStore: Bool = false) async throws {
        try await clearData(scope: .all)
        let accounts = try await accountRepository.fetchAll()
        for account in accounts { try await accountRepository.delete(account.id) }
        let categories = try await categoryRepository.fetchAll()
        for category in categories { try await categoryRepository.delete(category.id) }

        // Restore the out-of-the-box default categories so the app remains
        // immediately usable post-reset (matches a fresh-install experience).
        if let dataSeeder {
            try await dataSeeder.reseedDefaultCategories()
        }

        // Clear sensitive Keychain entries
        try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.onboardingComplete)
        try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.appLockEnabled)
        try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.appLockCooldown)
        try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.passcodeFallback)
        try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.userName)
        try await keychainService.delete(forKey: "com.vittora.encryption.key")
        try await keychainService.delete(forKey: "com.vittora.encryption.key.se_wrapped")

        AppLockSessionMirror.clearAll()
        AppUserDefaults.appGroup.removeObject(forKey: QuickAddDeepLink.pendingIntentDestinationKey)
        RecentErrorLogStore.shared.clear()

        UserDefaults.standard.removeObject(forKey: AppUserDefaults.SyncKey.lastSyncDate)
        AppUserDefaults.sync.removeObject(forKey: AppUserDefaults.SyncKey.lastSyncDate)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.categorizationRules)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.transactionEditHistory)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.savedTransactionFilters)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.spotlightIndexingEnabled)
        UserDefaults.standard.removeObject(forKey: TransactionSpotlightIndex.needsFullReindexKey)

        // Financial amounts must not outlive the ledger in Spotlight.
        await TransactionSpotlightIndex.deleteAllIndexedTransactions()

        if alsoDestroyOnDiskStore {
            try ModelContainerConfig.destroyPersistentStore()
        }
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
            for document in documents {
                try await documentStorageService.deleteDocument(for: document)
                try await documentStorageService.deleteThumbnail(for: document.id)
                try await documentRepository.delete(document.id)
            }
        } else {
            for document in documents {
                try await documentRepository.delete(document.id)
            }
        }
    }

    private func clearSpotlightAfterTransactionDeletion() async {
        await TransactionSpotlightIndex.deleteAllIndexedTransactions()
        if TransactionSpotlightIndex.isIndexingEnabled() {
            UserDefaults.standard.set(true, forKey: TransactionSpotlightIndex.needsFullReindexKey)
        }
    }
}
