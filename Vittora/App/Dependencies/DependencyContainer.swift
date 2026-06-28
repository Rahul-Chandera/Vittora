import SwiftUI
import SwiftData

@Observable
@MainActor
final class DependencyContainer {
    var transactionRepository: (any TransactionRepository)?
    var accountRepository: (any AccountRepository)?
    var categoryRepository: (any CategoryRepository)?
    var payeeRepository: (any PayeeRepository)?
    var budgetRepository: (any BudgetRepository)?
    var recurringRuleRepository: (any RecurringRuleRepository)?
    var documentRepository: (any DocumentRepository)?
    var debtRepository: (any DebtRepository)?
    var splitGroupRepository: (any SplitGroupRepository)?
    var taxProfileRepository: (any TaxProfileRepository)?
    var savingsGoalRepository: (any SavingsGoalRepository)?

    var ledgerWriteStore: LedgerWriteStore?

    /// Shared serializer for recurring generation so app-launch and background
    /// runs funnel through one in-flight run (DATAINTEGRITY-4).
    var recurringGenerationCoordinator: RecurringGenerationCoordinator?

    var biometricService: (any BiometricServiceProtocol)?
    var keychainService: (any KeychainServiceProtocol)?
    var encryptionService: (any EncryptionServiceProtocol)?
    var documentStorageService: (any DocumentStorageServiceProtocol)?
    var appLockService: (any AppLockServiceProtocol)?
    var exportService: (any DataExportServiceProtocol)?
    var contactsImportService: (any ContactsImportServiceProtocol)?
    var hapticService: (any HapticServiceProtocol) = LiveHapticService()
    var notificationService: (any NotificationServiceProtocol)?
    var evaluateBudgetThresholdAlertsUseCase: EvaluateBudgetThresholdAlertsUseCase?
    var securityAuditLogService: SecurityAuditLogService?
    var dataSeeder: (any DataSeederProtocol)?

    static func createDefault(modelContainer: ModelContainer) -> DependencyContainer {
        let container = DependencyContainer()

        container.transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        container.accountRepository = SwiftDataAccountRepository(modelContainer: modelContainer)
        container.categoryRepository = SwiftDataCategoryRepository(modelContainer: modelContainer)
        container.payeeRepository = SwiftDataPayeeRepository(modelContainer: modelContainer)
        container.budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        container.recurringRuleRepository = SwiftDataRecurringRuleRepository(modelContainer: modelContainer)
        container.debtRepository = SwiftDataDebtRepository(modelContainer: modelContainer)
        container.splitGroupRepository = SwiftDataSplitGroupRepository(modelContainer: modelContainer)
        container.taxProfileRepository = SwiftDataTaxProfileRepository(modelContainer: modelContainer)
        container.savingsGoalRepository = SwiftDataSavingsGoalRepository(modelContainer: modelContainer)
        let ledgerWriteStore = LedgerWriteStore(modelContainer: modelContainer)
        container.ledgerWriteStore = ledgerWriteStore
        container.dataSeeder = DefaultDataSeeder(modelContainer: modelContainer)

        if let recurringRuleRepository = container.recurringRuleRepository,
           let transactionRepository = container.transactionRepository,
           let accountRepository = container.accountRepository {
            let generateUseCase = GenerateRecurringTransactionsUseCase(
                ruleRepository: recurringRuleRepository,
                transactionRepository: transactionRepository,
                accountRepository: accountRepository,
                ledgerWriting: ledgerWriteStore
            )
            container.recurringGenerationCoordinator = RecurringGenerationCoordinator(useCase: generateUseCase)
        }

        let keychainService = KeychainService()
        let biometricService = BiometricService()
        let encryptionService = EncryptionService(keychainService: keychainService)
        let auditLogService = SecurityAuditLogService(encryptionService: encryptionService)
        container.securityAuditLogService = auditLogService
        container.keychainService = keychainService
        container.biometricService = biometricService
        container.encryptionService = encryptionService
        container.documentStorageService = EncryptedDocumentStorageService(
            encryptionService: encryptionService
        )
        if let documentStorageService = container.documentStorageService {
            container.documentRepository = EncryptedDocumentRepository(
                modelContainer: modelContainer,
                documentStorageService: documentStorageService
            )
        }
        container.appLockService = AppLockService(
            biometricService: biometricService,
            auditLogger: auditLogService
        )
        container.notificationService = NotificationService()
        if let budgetRepository = container.budgetRepository,
           let transactionRepository = container.transactionRepository,
           let notificationService = container.notificationService {
            let fetchBudgetsUseCase = FetchBudgetsUseCase(
                budgetRepository: budgetRepository,
                transactionRepository: transactionRepository
            )
            container.evaluateBudgetThresholdAlertsUseCase = EvaluateBudgetThresholdAlertsUseCase(
                budgetFetcher: fetchBudgetsUseCase,
                alertStore: UserDefaultsBudgetThresholdAlertStore(),
                notificationService: notificationService
            )
        }
        container.contactsImportService = SystemContactsImportService()
        if let transactionRepository = container.transactionRepository {
            container.exportService = DataExportService(
                transactionRepository: transactionRepository,
                accountRepository: container.accountRepository,
                categoryRepository: container.categoryRepository,
                payeeRepository: container.payeeRepository,
                auditLogger: auditLogService
            )
        }

        return container
    }
}
