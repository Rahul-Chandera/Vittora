import Foundation
import Testing
@testable import Vittora

@Suite("TransactionFormViewModel Tests")
@MainActor
struct TransactionFormViewModelTests {

    private func makeViewModel() -> (TransactionFormViewModel, MockTransactionRepository, MockAccountRepository, MockCategoryRepository) {
        let txRepo = MockTransactionRepository()
        let accountRepo = MockAccountRepository()
        let categoryRepo = MockCategoryRepository()
        let vm = TransactionFormViewModel(
            addUseCase: AddTransactionUseCase(
                transactionRepository: txRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            ),
            updateUseCase: UpdateTransactionUseCase(
                transactionRepository: txRepo,
                accountRepository: accountRepo
            ),
            smartCategorizeUseCase: SmartCategorizeUseCase(transactionRepository: txRepo),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: txRepo)
        )
        return (vm, txRepo, accountRepo, categoryRepo)
    }

    // MARK: - canSave

    @Test("canSave is false when amount is zero")
    func canSaveFalseWhenZeroAmount() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = "0"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == false)
    }

    @Test("canSave is false when no account selected")
    func canSaveFalseWhenNoAccount() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = "100"
        vm.selectedAccountID = nil
        #expect(vm.canSave == false)
    }

    @Test("canSave is false when amount string is empty")
    func canSaveFalseWhenEmptyString() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = ""
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == false)
    }

    @Test("canSave is true when amount > 0 and account is set")
    func canSaveTrueWhenValid() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = "49.99"
        vm.selectedAccountID = UUID()
        #expect(vm.canSave == true)
    }

    // MARK: - amount computed property

    @Test("amount parses valid decimal string")
    func amountParsesDecimalString() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = "123.45"
        #expect(vm.amount == Decimal(string: "123.45")!)
    }

    @Test("amount returns zero for invalid string")
    func amountZeroForInvalidString() {
        let (vm, _, _, _) = makeViewModel()
        vm.amountString = "abc"
        #expect(vm.amount == 0)
    }

    // MARK: - loadTransaction

    @Test("loadTransaction populates all fields from entity")
    func loadTransactionPopulatesFields() {
        let (vm, _, _, _) = makeViewModel()
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
        let (vm, _, _, _) = makeViewModel()
        vm.tagInput = "travel"
        vm.addTag()
        #expect(vm.tags == ["travel"])
        #expect(vm.tagInput == "")
    }

    @Test("addTag ignores empty input")
    func addTagIgnoresEmpty() {
        let (vm, _, _, _) = makeViewModel()
        vm.tagInput = "   "
        vm.addTag()
        #expect(vm.tags.isEmpty)
    }

    @Test("addTag ignores duplicate tag")
    func addTagIgnoresDuplicate() {
        let (vm, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.tagInput = "food"
        vm.addTag()
        #expect(vm.tags.count == 1)
    }

    @Test("removeTag removes matching tag")
    func removeTagRemovesMatch() {
        let (vm, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.tagInput = "travel"
        vm.addTag()
        vm.removeTag("food")
        #expect(vm.tags == ["travel"])
    }

    @Test("removeTag ignores non-existent tag")
    func removeTagIgnoresNonExistent() {
        let (vm, _, _, _) = makeViewModel()
        vm.tagInput = "food"
        vm.addTag()
        vm.removeTag("unknown")
        #expect(vm.tags == ["food"])
    }

    // MARK: - save()

    @Test("save throws validationFailed when canSave is false")
    func saveThrowsWhenCanSaveFalse() async {
        let (vm, _, _, _) = makeViewModel()
        // No amount or account set — canSave == false
        await #expect(throws: VittoraError.self) {
            try await vm.save()
        }
    }

    @Test("save creates new transaction via addUseCase")
    func saveCreatesNewTransaction() async throws {
        let (vm, txRepo, accountRepo, _) = makeViewModel()
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
        let (vm, txRepo, accountRepo, _) = makeViewModel()
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
        let (vm, txRepo, accountRepo, _) = makeViewModel()
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
        let (vm, txRepo, accountRepo, _) = makeViewModel()
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
        let (vm, _, _, _) = makeViewModel()
        vm.suggestedCategoryID = UUID()
        vm.selectedPayeeID = nil
        vm.amountString = "50"
        await vm.suggestCategory()
        #expect(vm.suggestedCategoryID == nil)
    }

    @Test("suggestCategory sets suggestion from payee transaction history")
    func suggestCategoryFromHistory() async {
        let (vm, txRepo, _, _) = makeViewModel()
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

    // MARK: - checkDuplicates

    @Test("checkDuplicates clears warning when no account selected")
    func checkDuplicatesClearsWithoutAccount() async {
        let (vm, _, _, _) = makeViewModel()
        vm.duplicateWarning = [TransactionEntity(amount: 10, type: .expense)]
        vm.selectedAccountID = nil
        vm.amountString = "10"
        await vm.checkDuplicates()
        #expect(vm.duplicateWarning.isEmpty)
    }

    @Test("checkDuplicates finds matching transaction")
    func checkDuplicatesFindsMatch() async {
        let (vm, txRepo, _, _) = makeViewModel()
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
