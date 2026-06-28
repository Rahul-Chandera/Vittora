import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Transaction Use Case Tests")
struct TransactionUseCaseTests {

    // MARK: - Helpers

    private static func makeAccount(
        balance: Decimal = 1000,
        isArchived: Bool = false
    ) -> AccountEntity {
        AccountEntity(name: "Checking", type: .bank, balance: balance, isArchived: isArchived)
    }

    private static func makeCategory() -> CategoryEntity {
        CategoryEntity(name: "Food", icon: "fork.knife", type: .expense)
    }

    // MARK: - AddTransactionUseCase

    @MainActor
    @Suite("AddTransactionUseCase")
    struct AddTransactionUseCaseTests {

        // A6: the use case writes through a real LedgerWriteStore, so these
        // tests exercise the real persistence path (account create via repo,
        // insert + balance adjust via the store) on one in-memory container.
        private struct Env {
            let accountRepo: SwiftDataAccountRepository
            let categoryRepo: SwiftDataCategoryRepository
            let txRepo: SwiftDataTransactionRepository
            let useCase: AddTransactionUseCase
        }

        private func makeEnv() throws -> Env {
            let container = try ModelContainerConfig.makeContainer(inMemory: true)
            let accountRepo = SwiftDataAccountRepository(modelContainer: container)
            let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)
            let txRepo = SwiftDataTransactionRepository(modelContainer: container)
            let store = LedgerWriteStore(modelContainer: container)
            let useCase = AddTransactionUseCase(
                accountRepository: accountRepo,
                categoryRepository: categoryRepo,
                ledgerWriting: store
            )
            return Env(accountRepo: accountRepo, categoryRepo: categoryRepo, txRepo: txRepo, useCase: useCase)
        }

        @Test("Creates a transaction and adjusts account balance for expense")
        func testExpenseDeductsBalance() async throws {
            let env = try makeEnv()
            let account = makeAccount(balance: 1000)
            try await env.accountRepo.create(account)

            let transaction = try await env.useCase.execute(
                amount: 200,
                type: .expense,
                date: .now,
                categoryID: nil,
                accountID: account.id,
                payeeID: nil,
                note: "Groceries",
                tags: [],
                paymentMethod: .debitCard,
                currencyCode: "USD"
            )

            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 800)
            let savedTransactions = try await env.txRepo.fetchAll(filter: nil)
            #expect(savedTransactions.count == 1)
            #expect(savedTransactions.first?.id == transaction.id)
        }

        @Test("Creates a transaction and increases account balance for income")
        func testIncomeAddsBalance() async throws {
            let env = try makeEnv()
            let account = makeAccount(balance: 500)
            try await env.accountRepo.create(account)

            _ = try await env.useCase.execute(
                amount: 300,
                type: .income,
                date: .now,
                categoryID: nil,
                accountID: account.id,
                payeeID: nil,
                note: nil,
                tags: [],
                paymentMethod: .bankTransfer,
                currencyCode: "USD"
            )

            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 800)
        }

        @Test("Adjustment adds to balance")
        func testAdjustmentAddsBalance() async throws {
            let env = try makeEnv()
            let account = makeAccount(balance: 100)
            try await env.accountRepo.create(account)

            _ = try await env.useCase.execute(
                amount: 50,
                type: .adjustment,
                date: .now,
                categoryID: nil,
                accountID: account.id,
                payeeID: nil,
                note: nil,
                tags: [],
                paymentMethod: .cash,
                currencyCode: "USD"
            )

            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 150)
        }

        @Test("Generic add rejects transfers — they must use performTransfer")
        func testRejectsTransferThroughGenericAdd() async throws {
            let env = try makeEnv()
            let account = makeAccount(balance: 1000)
            try await env.accountRepo.create(account)

            // A transfer routed through the single-leg add path would apply a
            // one-sided balance change; performAdd rejects it (DATAINTEGRITY-1).
            await #expect(throws: LedgerWriteError.self) {
                _ = try await env.useCase.execute(
                    amount: 200,
                    type: .transfer,
                    date: .now,
                    categoryID: nil,
                    accountID: account.id,
                    payeeID: nil,
                    note: nil,
                    tags: [],
                    paymentMethod: .bankTransfer,
                    currencyCode: "USD"
                )
            }

            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 1000)
            let savedTransactions = try await env.txRepo.fetchAll(filter: nil)
            #expect(savedTransactions.isEmpty)
        }

        @Test("Throws validation error for zero amount")
        func testThrowsForZeroAmount() async throws {
            let env = try makeEnv()
            let account = makeAccount()
            try await env.accountRepo.create(account)

            await #expect(throws: (any Error).self) {
                try await env.useCase.execute(
                    amount: 0,
                    type: .expense,
                    date: .now,
                    categoryID: nil,
                    accountID: account.id,
                    payeeID: nil,
                    note: nil,
                    tags: [],
                    paymentMethod: .cash,
                    currencyCode: "USD"
                )
            }
        }

        @Test("Throws when account does not exist")
        func testThrowsWhenAccountMissing() async throws {
            let env = try makeEnv()

            await #expect(throws: (any Error).self) {
                try await env.useCase.execute(
                    amount: 100,
                    type: .expense,
                    date: .now,
                    categoryID: nil,
                    accountID: UUID(),
                    payeeID: nil,
                    note: nil,
                    tags: [],
                    paymentMethod: .cash,
                    currencyCode: "USD"
                )
            }
        }

        @Test("Throws when account is archived")
        func testThrowsForArchivedAccount() async throws {
            let env = try makeEnv()
            let account = makeAccount(isArchived: true)
            try await env.accountRepo.create(account)

            await #expect(throws: (any Error).self) {
                try await env.useCase.execute(
                    amount: 100,
                    type: .expense,
                    date: .now,
                    categoryID: nil,
                    accountID: account.id,
                    payeeID: nil,
                    note: nil,
                    tags: [],
                    paymentMethod: .cash,
                    currencyCode: "USD"
                )
            }
        }

        @Test("Throws when category does not exist")
        func testThrowsWhenCategoryMissing() async throws {
            let env = try makeEnv()
            let account = makeAccount()
            try await env.accountRepo.create(account)

            await #expect(throws: (any Error).self) {
                try await env.useCase.execute(
                    amount: 100,
                    type: .expense,
                    date: .now,
                    categoryID: UUID(),
                    accountID: account.id,
                    payeeID: nil,
                    note: nil,
                    tags: [],
                    paymentMethod: .cash,
                    currencyCode: "USD"
                )
            }
        }

        @Test("Validates category exists when provided")
        func testAcceptsValidCategory() async throws {
            let env = try makeEnv()
            let account = makeAccount()
            let category = makeCategory()
            try await env.accountRepo.create(account)
            try await env.categoryRepo.create(category)

            let result = try await env.useCase.execute(
                amount: 50,
                type: .expense,
                date: .now,
                categoryID: category.id,
                accountID: account.id,
                payeeID: nil,
                note: nil,
                tags: [],
                paymentMethod: .cash,
                currencyCode: "USD"
            )

            #expect(result.categoryID == category.id)
        }
    }

    // MARK: - DeleteTransactionUseCase

    @MainActor
    @Suite("DeleteTransactionUseCase")
    struct DeleteTransactionUseCaseTests {

        @Test("Deletes a transaction and reverses expense balance effect")
        func testDeleteReversesBudgetEffect() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(800))
            await accountRepo.seed(account)

            let transaction = TransactionEntity(
                amount: 200,
                type: .expense,
                accountID: account.id
            )
            await transactionRepo.seed(transaction)

            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: MockDocumentRepository(),
                documentStorageService: MockDocumentStorageService(),
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(id: transaction.id)

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 1000)
            let remaining = await transactionRepo.transactions
            #expect(remaining.isEmpty)
        }

        @Test("Deletes a transaction and reverses income balance effect")
        func testDeleteReversesIncomeEffect() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(1300))
            await accountRepo.seed(account)

            let transaction = TransactionEntity(
                amount: 300,
                type: .income,
                accountID: account.id
            )
            await transactionRepo.seed(transaction)

            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: MockDocumentRepository(),
                documentStorageService: MockDocumentStorageService(),
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(id: transaction.id)

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 1000)
        }

        @Test("Bulk deletes multiple transactions")
        func testBulkDelete() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(700))
            await accountRepo.seed(account)

            let t1 = TransactionEntity(amount: 100, type: .expense, accountID: account.id)
            let t2 = TransactionEntity(amount: 200, type: .expense, accountID: account.id)
            await transactionRepo.seed(t1)
            await transactionRepo.seed(t2)

            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: MockDocumentRepository(),
                documentStorageService: MockDocumentStorageService(),
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.executeBulk(ids: [t1.id, t2.id])

            let remaining = await transactionRepo.transactions
            #expect(remaining.isEmpty)
        }

        @Test("Throws when transaction not found")
        func testThrowsWhenTransactionMissing() async throws {
            let transactionRepo = MockTransactionRepository()
            let accountRepo = MockAccountRepository()
            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: MockDocumentRepository(),
                documentStorageService: MockDocumentStorageService(),
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(id: UUID())
            }
        }

        @Test("Deletes linked documents before deleting transaction")
        func testDeleteRemovesLinkedDocuments() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let documentRepo = MockDocumentRepository()
            let documentStorage = MockDocumentStorageService()

            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(800))
            await accountRepo.seed(account)

            let transaction = TransactionEntity(
                amount: 200,
                type: .expense,
                accountID: account.id
            )
            await transactionRepo.seed(transaction)

            let linkedDocument = DocumentEntity(
                fileName: "receipt.jpg",
                mimeType: "image/jpeg",
                transactionID: transaction.id
            )
            await documentRepo.seed(linkedDocument)

            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: documentRepo,
                documentStorageService: documentStorage,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(id: transaction.id)

            let remainingDocuments = try await documentRepo.fetchForTransaction(transaction.id)
            #expect(remainingDocuments.isEmpty)
            #expect(documentStorage.deletedDocuments.contains(linkedDocument.id))
        }

        @Test("Deleting one transfer leg reverses BOTH legs and removes both rows")
        func deleteTransferReversesBothLegs() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            // Post-transfer state: source 750 (1000 − 250), dest 250 (0 + 250).
            let source = AccountEntity(name: "Source", type: .bank, balance: 750)
            let dest = AccountEntity(name: "Dest", type: .bank, balance: 250)
            await accountRepo.seed(source)
            await accountRepo.seed(dest)

            let pairID = UUID()
            let debit = TransactionEntity(
                amount: 250, type: .transfer,
                accountID: source.id, destinationAccountID: dest.id,
                transferPairID: pairID, transferDirection: .debit
            )
            let credit = TransactionEntity(
                amount: 250, type: .transfer,
                accountID: dest.id, destinationAccountID: source.id,
                transferPairID: pairID, transferDirection: .credit
            )
            await transactionRepo.seed(debit)
            await transactionRepo.seed(credit)

            let useCase = DeleteTransactionUseCase(
                transactionRepository: transactionRepo,
                documentRepository: MockDocumentRepository(),
                documentStorageService: MockDocumentStorageService(),
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            // Delete via ONE leg; both legs must go and both balances reverse.
            try await useCase.execute(id: debit.id)

            let remaining = await transactionRepo.transactions
            #expect(remaining.isEmpty)
            #expect(accountRepo.accounts.first { $0.id == source.id }?.balance == 1000)
            #expect(accountRepo.accounts.first { $0.id == dest.id }?.balance == 0)
        }
    }

    // MARK: - FetchTransactionsUseCase

    @MainActor
    @Suite("FetchTransactionsUseCase")
    struct FetchTransactionsUseCaseTests {

        @Test("Returns all transactions without filter")
        func testFetchAll() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 10, type: .expense))
            await repo.seed(TransactionEntity(amount: 20, type: .income))

            let useCase = FetchTransactionsUseCase(transactionRepository: repo)
            let result = try await useCase.execute(filter: nil)

            #expect(result.count == 2)
        }

        @Test("Groups transactions by calendar day")
        func testGroupedByDate() async throws {
            let repo = MockTransactionRepository()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

            await repo.seed(TransactionEntity(amount: 10, date: today, type: .expense))
            await repo.seed(TransactionEntity(amount: 20, date: today, type: .expense))
            await repo.seed(TransactionEntity(amount: 30, date: yesterday, type: .expense))

            let useCase = FetchTransactionsUseCase(transactionRepository: repo)
            let grouped = try await useCase.executeGroupedByDate(filter: nil)

            #expect(grouped.count == 2)
            let todayGroup = grouped.first { calendar.isDate($0.date, inSameDayAs: today) }
            #expect(todayGroup?.transactions.count == 2)
        }

        @Test("Filters transactions by type")
        func testFilterByType() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 100, type: .expense))
            await repo.seed(TransactionEntity(amount: 200, type: .income))

            let useCase = FetchTransactionsUseCase(transactionRepository: repo)
            let filter = TransactionFilter(types: [.expense])
            let result = try await useCase.execute(filter: filter)

            #expect(result.count == 1)
            #expect(result[0].type == .expense)
        }

        @Test("execute(id:) finds a transaction outside the fetchAll list window")
        func testFetchByIDBeyondListWindow() async throws {
            let repo = MockTransactionRepository()
            await repo.setFetchAllLimit(500)
            let calendar = Calendar.current
            let oldestDate = calendar.date(byAdding: .day, value: -600, to: .now) ?? .now
            let oldest = TransactionEntity(amount: 1, date: oldestDate, note: "Oldest", type: .expense)
            await repo.seed(oldest)

            for dayOffset in 0..<500 {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now
                await repo.seed(
                    TransactionEntity(amount: Decimal(dayOffset + 2), date: date, type: .expense)
                )
            }

            let useCase = FetchTransactionsUseCase(transactionRepository: repo)
            let listed = try await useCase.execute(filter: nil)
            #expect(listed.count == 500)
            #expect(listed.contains(where: { $0.id == oldest.id }) == false)

            let found = try await useCase.execute(id: oldest.id)
            #expect(found?.id == oldest.id)
            #expect(found?.note == "Oldest")
        }
    }

    // MARK: - SearchTransactionsUseCase

    @MainActor
    @Suite("SearchTransactionsUseCase")
    struct SearchTransactionsUseCaseTests {

        @Test("Returns empty array for blank query")
        func testEmptyQueryReturnsEmpty() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 50, note: "Coffee", type: .expense))

            let useCase = SearchTransactionsUseCase(transactionRepository: repo)
            let result = try await useCase.execute(query: "")

            #expect(result.isEmpty)
        }

        @Test("Returns empty array for whitespace-only query")
        func testWhitespaceQueryReturnsEmpty() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 50, note: "Coffee", type: .expense))

            let useCase = SearchTransactionsUseCase(transactionRepository: repo)
            let result = try await useCase.execute(query: "   ")

            #expect(result.isEmpty)
        }

        @Test("Returns matching transactions for valid query")
        func testValidQueryReturnsMatches() async throws {
            let repo = MockTransactionRepository()
            await repo.seed(TransactionEntity(amount: 5, note: "Coffee", type: .expense))
            await repo.seed(TransactionEntity(amount: 10, note: "Groceries", type: .expense))

            let useCase = SearchTransactionsUseCase(transactionRepository: repo)
            let result = try await useCase.execute(query: "Coffee")

            #expect(result.count == 1)
            #expect(result[0].note == "Coffee")
        }
    }

    // MARK: - UpdateTransactionUseCase

    @MainActor
    @Suite("UpdateTransactionUseCase")
    struct UpdateTransactionUseCaseTests {

        @Test("Updates transaction and recalculates account balance")
        func testUpdateAdjustsBalance() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            // Account starts at 800 (1000 - 200 from the existing expense)
            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(800))
            await accountRepo.seed(account)

            let original = TransactionEntity(
                amount: 200,
                type: .expense,
                accountID: account.id
            )
            await transactionRepo.seed(original)

            let useCase = UpdateTransactionUseCase(
                transactionRepository: transactionRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )

            // Change to a 100-expense: reverse 200 (+200), then apply 100 (-100) → net 900
            var updated = original
            updated.amount = 100

            try await useCase.execute(updated)

            let finalAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(finalAccount?.balance == 900)
        }

        @Test("Reverses income and applies new income amount")
        func testUpdateIncomeReversal() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            // Account at 1300: started at 1000, got 300 income
            let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(1300))
            await accountRepo.seed(account)

            let original = TransactionEntity(
                amount: 300,
                type: .income,
                accountID: account.id
            )
            await transactionRepo.seed(original)

            var updated = original
            updated.amount = 500  // Change income to 500

            let useCase = UpdateTransactionUseCase(
                transactionRepository: transactionRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(updated)

            // Reverse 300 income (-300 → 1000), apply 500 income (+500 → 1500)
            let finalAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(finalAccount?.balance == 1500)
        }

        @Test("Editing an expense to a different account adjusts both balances")
        func editChangingAccountUpdatesBothBalances() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            // Old account already reflects the original 200 expense (1000 - 200).
            let oldAccount = AccountEntity(name: "Old", type: .bank, balance: Decimal(800))
            let newAccount = AccountEntity(name: "New", type: .bank, balance: Decimal(500))
            await accountRepo.seed(oldAccount)
            await accountRepo.seed(newAccount)

            let original = TransactionEntity(
                amount: 200,
                type: .expense,
                accountID: oldAccount.id
            )
            await transactionRepo.seed(original)

            // Move the same expense to the new account.
            var moved = original
            moved.accountID = newAccount.id

            let useCase = UpdateTransactionUseCase(
                transactionRepository: transactionRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(moved)

            let finalOld = accountRepo.accounts.first { $0.id == oldAccount.id }
            let finalNew = accountRepo.accounts.first { $0.id == newAccount.id }
            // Old account: expense reversed (+200) -> 1000. New account: expense applied (-200) -> 300.
            #expect(finalOld?.balance == 1000)
            #expect(finalNew?.balance == 300)
        }

        @Test("Editing income to a different account moves the credit")
        func editChangingAccountMovesIncome() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let oldAccount = AccountEntity(name: "Old", type: .bank, balance: Decimal(1300))
            let newAccount = AccountEntity(name: "New", type: .bank, balance: Decimal(1000))
            await accountRepo.seed(oldAccount)
            await accountRepo.seed(newAccount)

            let original = TransactionEntity(
                amount: 300,
                type: .income,
                accountID: oldAccount.id
            )
            await transactionRepo.seed(original)

            var moved = original
            moved.accountID = newAccount.id

            let useCase = UpdateTransactionUseCase(
                transactionRepository: transactionRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )
            try await useCase.execute(moved)

            let finalOld = accountRepo.accounts.first { $0.id == oldAccount.id }
            let finalNew = accountRepo.accounts.first { $0.id == newAccount.id }
            // Old account: income reversed (-300) -> 1000. New account: income applied (+300) -> 1300.
            #expect(finalOld?.balance == 1000)
            #expect(finalNew?.balance == 1300)
        }

        @Test("Generic update rejects a transfer leg (Option B guard) and changes nothing")
        func updateRejectsTransferLeg() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let source = AccountEntity(name: "Source", type: .bank, balance: 750)
            await accountRepo.seed(source)

            let leg = TransactionEntity(
                amount: 250, type: .transfer,
                accountID: source.id, destinationAccountID: UUID(),
                transferPairID: UUID(), transferDirection: .debit
            )
            await transactionRepo.seed(leg)

            let useCase = UpdateTransactionUseCase(
                transactionRepository: transactionRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepo,
                    accountRepository: accountRepo
                )
            )

            var edited = leg
            edited.amount = 999

            await #expect(throws: VittoraError.self) {
                try await useCase.execute(edited)
            }

            // Nothing changed: balance and the stored leg are untouched.
            #expect(accountRepo.accounts.first { $0.id == source.id }?.balance == 750)
            let stored = await transactionRepo.transactions.first { $0.id == leg.id }
            #expect(stored?.amount == 250)
        }

        @Test("Throws when transaction does not exist")
        func testThrowsWhenTransactionMissing() async throws {
            let accountRepo = MockAccountRepository()
            let account = AccountEntity(name: "Bank", type: .bank, balance: 1000)
            await accountRepo.seed(account)

            let txRepo = MockTransactionRepository()
            let useCase = UpdateTransactionUseCase(
                transactionRepository: txRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: txRepo,
                    accountRepository: accountRepo
                )
            )

            let nonExistent = TransactionEntity(amount: 50, type: .expense, accountID: account.id)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(nonExistent)
            }
        }
    }
}

// MARK: - Seed helpers

extension MockTransactionRepository {
    func seed(_ entity: TransactionEntity) async {
        try? await create(entity)
    }
}
