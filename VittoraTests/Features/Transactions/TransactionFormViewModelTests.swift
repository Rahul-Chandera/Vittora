import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("TransactionFormViewModel Tests")
@MainActor
struct TransactionFormViewModelTests {

    private func makeViewModel(
        ruleStore: InMemoryCategorizationRuleStore = InMemoryCategorizationRuleStore()
    ) -> (TransactionFormViewModel, MockTransactionRepository, MockAccountRepository, MockCategoryRepository, InMemoryCategorizationRuleStore) {
        let txRepo = MockTransactionRepository()
        let accountRepo = MockAccountRepository()
        let categoryRepo = MockCategoryRepository()
        let vm = TransactionFormViewModel(
            addUseCase: AddTransactionUseCase(
                accountRepository: accountRepo,
                categoryRepository: categoryRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: txRepo,
                    accountRepository: accountRepo
                )
            ),
            updateUseCase: UpdateTransactionUseCase(
                transactionRepository: txRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: txRepo,
                    accountRepository: accountRepo
                )
            ),
            smartCategorizeUseCase: SmartCategorizeUseCase(
                transactionRepository: txRepo,
                ruleStore: ruleStore,
                categoryRepository: categoryRepo
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: txRepo)
        )
        return (vm, txRepo, accountRepo, categoryRepo, ruleStore)
    }

    // MARK: - canSave

    @Test("canSave is false when amount is zero")
    func canSaveFalseWhenZeroAmount() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = "0"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == false)
    }

    @Test("canSave is false when no account selected")
    func canSaveFalseWhenNoAccount() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = "100"
        vm.selectedAccountID = nil
        #expect(vm.canSave == false)
    }

    @Test("canSave is false when amount string is empty")
    func canSaveFalseWhenEmptyString() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = ""
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == false)
    }

    @Test("canSave is true when amount > 0 and account is set")
    func canSaveTrueWhenValid() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = "49.99"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == true)
    }

    // MARK: - default account selection (regression: Save disabled with >1 account)

    @Test("selectDefaultAccountIfNeeded picks the first account when none selected — even with multiple")
    func defaultsFirstAccountWithMultiple() {
        let (vm, _, _, _, _) = makeViewModel()
        let first = AccountEntity(name: "Checking", type: .bank)
        let second = AccountEntity(name: "Savings", type: .bank)
        vm.selectedAccountID = nil

        vm.selectDefaultAccountIfNeeded(from: [first, second])

        #expect(vm.selectedAccountID == first.id)
        vm.amountString = "311000"
        #expect(vm.canSave == true) // Save is now enabled without the user touching the picker
    }

    @Test("selectDefaultAccountIfNeeded does not override an already-selected account (edit path)")
    func doesNotOverrideExistingSelection() {
        let (vm, _, _, _, _) = makeViewModel()
        let existing = UUID()
        vm.selectedAccountID = existing

        vm.selectDefaultAccountIfNeeded(from: [AccountEntity(name: "Other", type: .cash)])

        #expect(vm.selectedAccountID == existing)
    }

    @Test("selectDefaultAccountIfNeeded is a safe no-op with no accounts")
    func noOpWhenNoAccounts() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.selectedAccountID = nil

        vm.selectDefaultAccountIfNeeded(from: [])

        #expect(vm.selectedAccountID == nil)
    }

    // MARK: - localized amount parsing

    @Test("canSave accepts a locale-valid decimal string")
    func canSaveWithValidAmount() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = "123.45"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == true)
    }

    @Test("canSave rejects unparseable amount instead of silently coercing to zero")
    func canSaveFalseForInvalidString() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.amountString = "abc"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == false)
    }

    // MARK: - loadTransaction

    @Test("loadTransaction populates all fields from entity")
    func loadTransactionPopulatesFields() {
        let (vm, _, _, _, _) = makeViewModel()
        let accountID = UUID()
        let payeeID = UUID()
        let categoryID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entity = TransactionEntity(
            amount: Decimal(string: "250.00")!,
            date: date,
            note: "Groceries",
            type: .expense,
            paymentMethod: .debitCard,
            tags: ["food", "weekly"],
            categoryID: categoryID,
            accountID: accountID,
            payeeID: payeeID
        )

        vm.loadTransaction(entity)

        #expect(vm.isEditing == true)
        #expect(vm.editingID == entity.id)
        #expect(vm.type == .expense)
        #expect(vm.date == date)
        #expect(vm.selectedCategoryID == categoryID)
        #expect(vm.selectedAccountID == accountID)
        #expect(vm.selectedPayeeID == payeeID)
        #expect(vm.note == "Groceries")
        #expect(vm.tags == ["food", "weekly"])
        #expect(vm.paymentMethod == .debitCard)
    }

    // MARK: - addTag / removeTag

    @Test("addTag appends tag and clears tagInput")
    func addTagAppendsAndClears() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.tagInput = "travel"
        vm.addTag()
        #expect(vm.tags == ["travel"])
        #expect(vm.tagInput == "")
    }

    @Test("addTag ignores empty input")
    func addTagIgnoresEmpty() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.tagInput = "   "
        vm.addTag()
        #expect(vm.tags.isEmpty)
    }

    @Test("addTag ignores duplicate tag")
    func addTagIgnoresDuplicate() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.tagInput = "food"
        vm.addTag()
        #expect(vm.tags.count == 1)
    }

    @Test("removeTag removes matching tag")
    func removeTagRemovesMatch() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.tagInput = "travel"
        vm.addTag()
        vm.removeTag("food")
        #expect(vm.tags == ["travel"])
    }

    @Test("removeTag ignores non-existent tag")
    func removeTagIgnoresNonExistent() {
        let (vm, _, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.removeTag("unknown")
        #expect(vm.tags == ["food"])
    }

    // MARK: - save()

    @Test("save throws validationFailed when canSave is false")
    func saveThrowsWhenCanSaveFalse() async {
        let (vm, _, _, _, _) = makeViewModel()
        // No amount or account set — canSave == false
        await #expect(throws: VittoraError.self) {
            try await vm.save()
        }
    }

    @Test("save creates new transaction via addUseCase")
    func saveCreatesNewTransaction() async throws {
        let (vm, txRepo, accountRepo, _, _) = makeViewModel()
        let account = AccountEntity(name: "Wallet", type: .cash, balance: 1000)
        await accountRepo.seed(account)

        vm.amountString = "75"
        vm.selectedAccountID = account.id
        vm.type = .expense

        try await vm.save()

        let all = await txRepo.transactions
        #expect(all.count == 1)
        #expect(all.first?.amount == 75)
        #expect(all.first?.type == .expense)
        #expect(all.first?.accountID == account.id)
    }

    @Test("save stores note and tags in transaction")
    func saveStoresNoteAndTags() async throws {
        let (vm, txRepo, accountRepo, _, _) = makeViewModel()
        let account = AccountEntity(name: "Bank", type: .bank, balance: 500)
        await accountRepo.seed(account)

        vm.amountString = "20"
        vm.selectedAccountID = account.id
        vm.note = "Coffee"
        vm.tagInput = "daily"
        vm.addTag()

        try await vm.save()

        let all = await txRepo.transactions
        #expect(all.first?.note == "Coffee")
        #expect(all.first?.tags == ["daily"])
    }

    @Test("save empty note is stored as nil")
    func saveEmptyNoteStoredAsNil() async throws {
        let (vm, txRepo, accountRepo, _, _) = makeViewModel()
        let account = AccountEntity(name: "Bank", type: .bank, balance: 500)
        await accountRepo.seed(account)

        vm.amountString = "10"
        vm.selectedAccountID = account.id
        vm.note = ""

        try await vm.save()

        let all = await txRepo.transactions
        #expect(all.first?.note == nil)
    }

    @Test("save in editing mode updates existing transaction")
    func saveInEditingModeUpdates() async throws {
        let (vm, txRepo, accountRepo, _, _) = makeViewModel()
        let account = AccountEntity(name: "Bank", type: .bank, balance: 1000)
        await accountRepo.seed(account)

        let original = TransactionEntity(
            amount: 100, type: .expense, accountID: account.id
        )
        await txRepo.seed(original)

        vm.loadTransaction(original)
        vm.amountString = "200"

        try await vm.save()

        let updated = await txRepo.transactions.first { $0.id == original.id }
        #expect(updated?.amount == 200)
    }

    // MARK: - suggestCategory

    @Test("suggestCategory clears suggestion when no payee")
    func suggestCategoryNilWhenNoPayee() async {
        let (vm, _, _, _, _) = makeViewModel()
        vm.suggestedCategoryID = UUID()
        vm.selectedPayeeID = nil
        vm.amountString = "50"
        await vm.suggestCategory()
        #expect(vm.suggestedCategoryID == nil)
    }

    @Test("suggestCategory sets suggestion from payee transaction history")
    func suggestCategoryFromHistory() async {
        let (vm, txRepo, _, _, ruleStore) = makeViewModel()
        let payeeID = UUID()
        let categoryID = UUID()

        let pastTx = TransactionEntity(
            amount: 10, type: .expense,
            categoryID: categoryID, payeeID: payeeID
        )
        await txRepo.seed(pastTx)

        vm.selectedPayeeID = payeeID
        vm.amountString = "10"
        await vm.suggestCategory()

        #expect(vm.suggestedCategoryID == categoryID)
    }

    @Test("suggestCategory sets suggestion from keyword rule in note")
    func suggestCategoryFromRuleNote() async throws {
        let (vm, _, _, categoryRepo, ruleStore) = makeViewModel()
        let categoryID = UUID()

        try await categoryRepo.create(
            CategoryEntity(id: categoryID, name: "Streaming", icon: "play.tv", colorHex: "#FF0000", type: .expense)
        )
        try ruleStore.save(CategorizationRule(keyword: "netflix", categoryID: categoryID))

        vm.amountString = "15"
        vm.note = "Netflix monthly"
        await vm.suggestCategory()

        #expect(vm.suggestedCategoryID == categoryID)
    }

    // MARK: - checkDuplicates

    @Test("checkDuplicates clears warning when no account selected")
    func checkDuplicatesClearsWithoutAccount() async {
        let (vm, _, _, _, _) = makeViewModel()
        vm.duplicateWarning = [TransactionEntity(amount: 10, type: .expense)]
        vm.selectedAccountID = nil
        vm.amountString = "10"
        await vm.checkDuplicates()
        #expect(vm.duplicateWarning.isEmpty)
    }

    @Test("checkDuplicates finds matching transaction")
    func checkDuplicatesFindsMatch() async {
        let (vm, txRepo, _, _, ruleStore) = makeViewModel()
        let accountID = UUID()
        let payeeID = UUID()

        let now = Date()
        let existing = TransactionEntity(
            amount: 50,
            date: now,
            type: .expense,
            accountID: accountID,
            payeeID: payeeID
        )
        await txRepo.seed(existing)

        vm.amountString = "50"
        vm.selectedAccountID = accountID
        vm.selectedPayeeID = payeeID
        vm.date = now

        await vm.checkDuplicates()

        #expect(vm.duplicateWarning.count == 1)
        #expect(vm.duplicateWarning.first?.id == existing.id)
    }
}
