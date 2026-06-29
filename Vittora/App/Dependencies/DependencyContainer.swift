import SwiftUI
import SwiftData
import OSLog

@Observable
@MainActor
final class DependencyContainer {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let categoryRepository: any CategoryRepository
    let payeeRepository: any PayeeRepository
    let budgetRepository: any BudgetRepository
    let recurringRuleRepository: any RecurringRuleRepository
    let documentRepository: any DocumentRepository
    let debtRepository: any DebtRepository
    let splitGroupRepository: any SplitGroupRepository
    let taxProfileRepository: any TaxProfileRepository
    let savingsGoalRepository: any SavingsGoalRepository

    let ledgerWriteStore: LedgerWriteStore

    /// Shared serializer for recurring generation so app-launch and background
    /// runs funnel through one in-flight run (DATAINTEGRITY-4).
    let recurringGenerationCoordinator: RecurringGenerationCoordinator

    let biometricService: any BiometricServiceProtocol
    let keychainService: any KeychainServiceProtocol
    let encryptionService: any EncryptionServiceProtocol
    let documentStorageService: any DocumentStorageServiceProtocol
    let appLockService: any AppLockServiceProtocol
    let exportService: any DataExportServiceProtocol
    let contactsImportService: any ContactsImportServiceProtocol
    var hapticService: any HapticServiceProtocol = LiveHapticService()
    let notificationService: any NotificationServiceProtocol
    let evaluateBudgetThresholdAlertsUseCase: EvaluateBudgetThresholdAlertsUseCase
    let scheduleCreditCardDueRemindersUseCase: ScheduleCreditCardDueRemindersUseCase
    let scheduleRecurringPreNotificationsUseCase: ScheduleRecurringPreNotificationsUseCase
    let scheduleSelfDebtDueRemindersUseCase: ScheduleSelfDebtDueRemindersUseCase
    var conversionEventTracker: any ConversionEventTracking = UserDefaultsConversionEventTracker()
    let conversionEventRecorder: ConversionEventRecorder
    let securityAuditLogService: SecurityAuditLogService
    let dataSeeder: any DataSeederProtocol

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        payeeRepository: any PayeeRepository,
        budgetRepository: any BudgetRepository,
        recurringRuleRepository: any RecurringRuleRepository,
        documentRepository: any DocumentRepository,
        debtRepository: any DebtRepository,
        splitGroupRepository: any SplitGroupRepository,
        taxProfileRepository: any TaxProfileRepository,
        savingsGoalRepository: any SavingsGoalRepository,
        ledgerWriteStore: LedgerWriteStore,
        recurringGenerationCoordinator: RecurringGenerationCoordinator,
        biometricService: any BiometricServiceProtocol,
        keychainService: any KeychainServiceProtocol,
        encryptionService: any EncryptionServiceProtocol,
        documentStorageService: any DocumentStorageServiceProtocol,
        appLockService: any AppLockServiceProtocol,
        exportService: any DataExportServiceProtocol,
        contactsImportService: any ContactsImportServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        evaluateBudgetThresholdAlertsUseCase: EvaluateBudgetThresholdAlertsUseCase,
        scheduleCreditCardDueRemindersUseCase: ScheduleCreditCardDueRemindersUseCase,
        scheduleRecurringPreNotificationsUseCase: ScheduleRecurringPreNotificationsUseCase,
        scheduleSelfDebtDueRemindersUseCase: ScheduleSelfDebtDueRemindersUseCase,
        conversionEventRecorder: ConversionEventRecorder,
        securityAuditLogService: SecurityAuditLogService,
        dataSeeder: any DataSeederProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.payeeRepository = payeeRepository
        self.budgetRepository = budgetRepository
        self.recurringRuleRepository = recurringRuleRepository
        self.documentRepository = documentRepository
        self.debtRepository = debtRepository
        self.splitGroupRepository = splitGroupRepository
        self.taxProfileRepository = taxProfileRepository
        self.savingsGoalRepository = savingsGoalRepository
        self.ledgerWriteStore = ledgerWriteStore
        self.recurringGenerationCoordinator = recurringGenerationCoordinator
        self.biometricService = biometricService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        self.documentStorageService = documentStorageService
        self.appLockService = appLockService
        self.exportService = exportService
        self.contactsImportService = contactsImportService
        self.notificationService = notificationService
        self.evaluateBudgetThresholdAlertsUseCase = evaluateBudgetThresholdAlertsUseCase
        self.scheduleCreditCardDueRemindersUseCase = scheduleCreditCardDueRemindersUseCase
        self.scheduleRecurringPreNotificationsUseCase = scheduleRecurringPreNotificationsUseCase
        self.scheduleSelfDebtDueRemindersUseCase = scheduleSelfDebtDueRemindersUseCase
        self.conversionEventRecorder = conversionEventRecorder
        self.securityAuditLogService = securityAuditLogService
        self.dataSeeder = dataSeeder
    }

    static func createDefault(modelContainer: ModelContainer) -> DependencyContainer {
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        let accountRepository = SwiftDataAccountRepository(modelContainer: modelContainer)
        let categoryRepository = SwiftDataCategoryRepository(modelContainer: modelContainer)
        let payeeRepository = SwiftDataPayeeRepository(modelContainer: modelContainer)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        let recurringRuleRepository = SwiftDataRecurringRuleRepository(modelContainer: modelContainer)
        let debtRepository = SwiftDataDebtRepository(modelContainer: modelContainer)
        let splitGroupRepository = SwiftDataSplitGroupRepository(modelContainer: modelContainer)
        let taxProfileRepository = SwiftDataTaxProfileRepository(modelContainer: modelContainer)
        let savingsGoalRepository = SwiftDataSavingsGoalRepository(modelContainer: modelContainer)
        let ledgerWriteStore = LedgerWriteStore(modelContainer: modelContainer)
        let dataSeeder = DefaultDataSeeder(modelContainer: modelContainer)

        let generateUseCase = GenerateRecurringTransactionsUseCase(
            ruleRepository: recurringRuleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            ledgerWriting: ledgerWriteStore
        )
        let recurringGenerationCoordinator = RecurringGenerationCoordinator(useCase: generateUseCase)

        let keychainService = KeychainService()
        let biometricService = BiometricService()
        let encryptionService = EncryptionService(keychainService: keychainService)
        let auditLogService = SecurityAuditLogService(encryptionService: encryptionService)
        let documentStorageService = EncryptedDocumentStorageService(
            encryptionService: encryptionService
        )
        let documentRepository = EncryptedDocumentRepository(
            modelContainer: modelContainer,
            documentStorageService: documentStorageService
        )
        let appLockService = AppLockService(
            biometricService: biometricService,
            auditLogger: auditLogService
        )
        let notificationService = NotificationService()

        let fetchBudgetsUseCase = FetchBudgetsUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        let evaluateBudgetThresholdAlertsUseCase = EvaluateBudgetThresholdAlertsUseCase(
            budgetFetcher: fetchBudgetsUseCase,
            alertStore: UserDefaultsBudgetThresholdAlertStore(),
            notificationService: notificationService
        )
        let scheduleCreditCardDueRemindersUseCase = ScheduleCreditCardDueRemindersUseCase(
            accountRepository: accountRepository,
            notificationService: notificationService
        )
        let scheduleRecurringPreNotificationsUseCase = ScheduleRecurringPreNotificationsUseCase(
            ruleRepository: recurringRuleRepository,
            payeeRepository: payeeRepository,
            notificationService: notificationService
        )
        let scheduleSelfDebtDueRemindersUseCase = ScheduleSelfDebtDueRemindersUseCase(
            debtRepository: debtRepository,
            payeeRepository: payeeRepository,
            notificationService: notificationService
        )
        let contactsImportService = SystemContactsImportService()
        let exportService = DataExportService(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            payeeRepository: payeeRepository,
            auditLogger: auditLogService
        )
        let conversionEventTracker = UserDefaultsConversionEventTracker()
        let conversionEventRecorder = ConversionEventRecorder(
            tracker: conversionEventTracker,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            budgetRepository: budgetRepository
        )

        return DependencyContainer(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            payeeRepository: payeeRepository,
            budgetRepository: budgetRepository,
            recurringRuleRepository: recurringRuleRepository,
            documentRepository: documentRepository,
            debtRepository: debtRepository,
            splitGroupRepository: splitGroupRepository,
            taxProfileRepository: taxProfileRepository,
            savingsGoalRepository: savingsGoalRepository,
            ledgerWriteStore: ledgerWriteStore,
            recurringGenerationCoordinator: recurringGenerationCoordinator,
            biometricService: biometricService,
            keychainService: keychainService,
            encryptionService: encryptionService,
            documentStorageService: documentStorageService,
            appLockService: appLockService,
            exportService: exportService,
            contactsImportService: contactsImportService,
            notificationService: notificationService,
            evaluateBudgetThresholdAlertsUseCase: evaluateBudgetThresholdAlertsUseCase,
            scheduleCreditCardDueRemindersUseCase: scheduleCreditCardDueRemindersUseCase,
            scheduleRecurringPreNotificationsUseCase: scheduleRecurringPreNotificationsUseCase,
            scheduleSelfDebtDueRemindersUseCase: scheduleSelfDebtDueRemindersUseCase,
            conversionEventRecorder: conversionEventRecorder,
            securityAuditLogService: auditLogService,
            dataSeeder: dataSeeder
        )
    }

    /// Wiring used when the persistent store fails. The scene shows `StartupFailureView`
    /// without attaching a `ModelContainer`, so this ephemeral graph is not user-facing data.
    static func startupFailure() -> DependencyContainer {
        let containerCreators: [() throws -> ModelContainer] = [
            { try ModelContainerConfig.makeEphemeralWiringContainer() },
            { try ModelContainerConfig.makeContainer(inMemory: true) },
            { try ModelContainerConfig.makePreviewContainer() },
        ]
        for create in containerCreators {
            if let container = try? create() {
                return createDefault(modelContainer: container)
            }
        }
        #if DEBUG
        fatalError("DependencyContainer.startupFailure failed")
        #else
        Logger(subsystem: "com.vittora.app", category: "startup").fault(
            "All startupFailure container attempts failed; app cannot wire dependencies."
        )
        fatalError("DependencyContainer.startupFailure failed")
        #endif
    }

    /// Preview and SwiftUI environment fallback wiring.
    static func preview() -> DependencyContainer {
        do {
            return createDefault(modelContainer: try ModelContainerConfig.makePreviewContainer())
        } catch {
            #if DEBUG
            fatalError("DependencyContainer.preview failed: \(error)")
            #else
            preconditionFailure("DependencyContainer.preview is unavailable in release builds")
            #endif
        }
    }
}
