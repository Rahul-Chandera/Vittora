import Foundation
import VittoraCore

extension DependencyContainer {
    func makeTransactionListViewModel() -> TransactionListViewModel {
        let fetchUseCase = FetchTransactionsUseCase(transactionRepository: transactionRepository)
        let searchUseCase = SearchTransactionsUseCase(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository,
            payeeRepository: payeeRepository
        )
        let deleteUseCase = DeleteTransactionUseCase(
            transactionRepository: transactionRepository,
            documentRepository: documentRepository,
            documentStorageService: documentStorageService,
            ledgerWriting: ledgerWriteStore,
            editHistoryStore: transactionEditHistoryStore
        )
        return TransactionListViewModel(
            fetchUseCase: fetchUseCase,
            searchUseCase: searchUseCase,
            deleteUseCase: deleteUseCase,
            bulkOpsUseCase: BulkOperationsUseCase(transactionRepository: transactionRepository),
            addUseCase: AddTransactionUseCase(
                accountRepository: accountRepository,
                categoryRepository: categoryRepository,
                ledgerWriting: ledgerWriteStore
            ),
            categoryRepository: categoryRepository
        )
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        let dataUseCase = DashboardDataUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            budgetRepository: budgetRepository,
            recurringRuleRepository: recurringRuleRepository
        )
        return DashboardViewModel(
            dashboardDataUseCase: dataUseCase,
            monthComparisonUseCase: MonthComparisonUseCase(transactionRepository: transactionRepository)
        )
    }

    func makeAccountListViewModel() -> AccountListViewModel {
        AccountListViewModel(
            fetchAccountsUseCase: FetchAccountsUseCase(accountRepository: accountRepository),
            calculateNetWorthUseCase: CalculateNetWorthUseCase(accountRepository: accountRepository),
            deleteAccountUseCase: DeleteAccountUseCase(
                accountRepository: accountRepository,
                transactionRepository: transactionRepository
            )
        )
    }

    func makeCategoryListViewModel() -> CategoryListViewModel {
        CategoryListViewModel(
            fetchUseCase: FetchCategoriesUseCase(repository: categoryRepository),
            deleteUseCase: DeleteCategoryUseCase(
                categoryRepository: categoryRepository,
                ledgerWriting: ledgerWriteStore
            ),
            reorderUseCase: ReorderCategoriesUseCase(repository: categoryRepository)
        )
    }

    func makePayeeListViewModel() -> PayeeListViewModel {
        PayeeListViewModel(
            fetchUseCase: FetchPayeesUseCase(repository: payeeRepository),
            deleteUseCase: DeletePayeeUseCase(
                repository: payeeRepository,
                transactionRepository: transactionRepository
            ),
            importContactsUseCase: ImportContactsUseCase(
                repository: payeeRepository,
                contactsService: contactsImportService
            )
        )
    }

    func makeRecurringListViewModel() -> RecurringListViewModel {
        RecurringListViewModel(
            fetchUseCase: FetchRecurringRulesUseCase(repository: recurringRuleRepository),
            deleteUseCase: DeleteRecurringRuleUseCase(
                repository: recurringRuleRepository,
                ledgerWriting: ledgerWriteStore
            ),
            pauseResumeUseCase: PauseResumeRuleUseCase(repository: recurringRuleRepository),
            calculateCostUseCase: CalculateSubscriptionCostUseCase(),
            categoryRepository: categoryRepository
        )
    }

    func makeBudgetListViewModel() -> BudgetListViewModel {
        BudgetListViewModel(
            fetchUseCase: FetchBudgetsUseCase(
                budgetRepository: budgetRepository,
                transactionRepository: transactionRepository
            ),
            deleteUseCase: DeleteBudgetUseCase(budgetRepository: budgetRepository),
            calculateProgressUseCase: CalculateBudgetProgressUseCase(),
            categoryRepository: categoryRepository
        )
    }

    func makeTransactionFormViewModel(currencyCode: String) -> TransactionFormViewModel {
        TransactionFormViewModel(
            addUseCase: AddTransactionUseCase(
                accountRepository: accountRepository,
                categoryRepository: categoryRepository,
                ledgerWriting: ledgerWriteStore
            ),
            updateUseCase: UpdateTransactionUseCase(
                transactionRepository: transactionRepository,
                ledgerWriting: ledgerWriteStore,
                recordEditUseCase: RecordTransactionEditUseCase(store: transactionEditHistoryStore)
            ),
            smartCategorizeUseCase: SmartCategorizeUseCase(
                transactionRepository: transactionRepository,
                ruleStore: categorizationRuleStore,
                categoryRepository: categoryRepository
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: transactionRepository),
            currencyCode: currencyCode
        )
    }

    func makeQuickEntryViewModel(currencyCode: String) -> TransactionFormViewModel {
        let vm = makeTransactionFormViewModel(currencyCode: currencyCode)
        vm.isQuickEntry = true
        vm.type = .expense
        return vm
    }

    func makeTransactionDetailViewModel() -> TransactionDetailViewModel {
        TransactionDetailViewModel(
            fetchUseCase: FetchTransactionsUseCase(transactionRepository: transactionRepository),
            deleteUseCase: DeleteTransactionUseCase(
                transactionRepository: transactionRepository,
                documentRepository: documentRepository,
                documentStorageService: documentStorageService,
                ledgerWriting: ledgerWriteStore,
                editHistoryStore: transactionEditHistoryStore
            ),
            editHistoryStore: transactionEditHistoryStore,
            categoryRepository: categoryRepository,
            accountRepository: accountRepository
        )
    }

    func makeBatchScanUseCase() -> BatchScanUseCase {
        BatchScanUseCase(ocrService: OCRService())
    }

    func makeManageSavedTransactionFiltersUseCase() -> ManageSavedTransactionFiltersUseCase {
        ManageSavedTransactionFiltersUseCase(store: savedTransactionFilterStore)
    }

    func makeTransactionCSVImportViewModel() -> TransactionCSVImportViewModel {
        TransactionCSVImportViewModel(
            importUseCase: ImportTransactionsFromCSVUseCase(
                addTransactionUseCase: AddTransactionUseCase(
                    accountRepository: accountRepository,
                    categoryRepository: categoryRepository,
                    ledgerWriting: ledgerWriteStore
                ),
                duplicateDetectionUseCase: DuplicateDetectionUseCase(
                    transactionRepository: transactionRepository
                ),
                payeeRepository: payeeRepository,
                categoryRepository: categoryRepository
            ),
            fetchAccountsUseCase: FetchAccountsUseCase(accountRepository: accountRepository)
        )
    }

    func makeDebtLedgerViewModel() -> DebtLedgerViewModel {
        DebtLedgerViewModel(
            fetchLedgerUseCase: FetchDebtLedgerUseCase(
                debtRepository: debtRepository,
                payeeRepository: payeeRepository
            ),
            calculateBalanceUseCase: CalculateDebtBalanceUseCase(debtRepository: debtRepository),
            fetchOverdueUseCase: FetchOverdueDebtsUseCase(debtRepository: debtRepository)
        )
    }

    func makeSplitGroupListViewModel() -> SplitGroupListViewModel {
        SplitGroupListViewModel(
            fetchGroupsUseCase: FetchSplitGroupsUseCase(
                splitGroupRepository: splitGroupRepository,
                payeeRepository: payeeRepository
            ),
            createGroupUseCase: CreateSplitGroupUseCase(splitGroupRepository: splitGroupRepository),
            splitGroupRepository: splitGroupRepository
        )
    }

    func makeSavingsGoalListViewModel() -> SavingsGoalListViewModel {
        SavingsGoalListViewModel(
            fetchUseCase: FetchSavingsGoalsUseCase(savingsGoalRepository: savingsGoalRepository),
            saveUseCase: SaveSavingsGoalUseCase(savingsGoalRepository: savingsGoalRepository)
        )
    }

    func makeCategorizationRulesViewModel() -> CategorizationRulesViewModel {
        CategorizationRulesViewModel(
            manageRulesUseCase: ManageCategorizationRulesUseCase(
                ruleStore: categorizationRuleStore,
                categoryRepository: categoryRepository
            ),
            fetchCategoriesUseCase: FetchCategoriesUseCase(repository: categoryRepository)
        )
    }

    func makeDataManagementService() -> DataManagementService {
        DataManagementService(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            budgetRepository: budgetRepository,
            debtRepository: debtRepository,
            savingsGoalRepository: savingsGoalRepository,
            splitGroupRepository: splitGroupRepository,
            documentRepository: documentRepository,
            payeeRepository: payeeRepository,
            recurringRuleRepository: recurringRuleRepository,
            taxProfileRepository: taxProfileRepository,
            documentStorageService: documentStorageService,
            keychainService: keychainService,
            dataSeeder: dataSeeder
        )
    }
}
