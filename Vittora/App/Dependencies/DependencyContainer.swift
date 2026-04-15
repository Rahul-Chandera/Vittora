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

    var biometricService: (any BiometricServiceProtocol)?
    var keychainService: (any KeychainServiceProtocol)?
    var encryptionService: (any EncryptionServiceProtocol)?
    var appLockService: (any AppLockServiceProtocol)?
    var exportService: (any DataExportServiceProtocol)?

    static func createDefault(modelContainer: ModelContainer) -> DependencyContainer {
        let container = DependencyContainer()

        container.transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        container.accountRepository = SwiftDataAccountRepository(modelContainer: modelContainer)
        container.categoryRepository = SwiftDataCategoryRepository(modelContainer: modelContainer)
        container.payeeRepository = SwiftDataPayeeRepository(modelContainer: modelContainer)
        container.budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        container.recurringRuleRepository = SwiftDataRecurringRuleRepository(modelContainer: modelContainer)
        container.documentRepository = SwiftDataDocumentRepository(modelContainer: modelContainer)
        container.debtRepository = SwiftDataDebtRepository(modelContainer: modelContainer)
        container.splitGroupRepository = SwiftDataSplitGroupRepository(modelContainer: modelContainer)
        container.taxProfileRepository = SwiftDataTaxProfileRepository(modelContainer: modelContainer)
        container.savingsGoalRepository = SwiftDataSavingsGoalRepository(modelContainer: modelContainer)

        let keychainService = KeychainService()
        container.keychainService = keychainService
        container.biometricService = BiometricService()
        container.encryptionService = EncryptionService(keychainService: keychainService)
        container.appLockService = AppLockService(biometricService: BiometricService())
        container.exportService = DataExportService(
            transactionRepository: container.transactionRepository!,
            accountRepository: container.accountRepository,
            categoryRepository: container.categoryRepository,
            payeeRepository: container.payeeRepository
        )

        return container
    }
}
