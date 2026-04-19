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

        @Test("Creates a transaction and adjusts account balance for expense")
        func testExpenseDeductsBalance() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let categoryRepo = MockCategoryRepository()

            let account = makeAccount(balance: 1000)
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            )

            let transaction = try await useCase.execute(
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

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 800)
            let savedTransactions = await transactionRepo.transactions
            #expect(savedTransactions.count == 1)
            #expect(savedTransactions[0].id == transaction.id)
        }

        @Test("Creates a transaction and increases account balance for income")
        func testIncomeAddsBalance() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let categoryRepo = MockCategoryRepository()

            let account = makeAccount(balance: 500)
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            )

            _ = try await useCase.execute(
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

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 800)
        }

        @Test("Adjustment adds to balance")
        func testAdjustmentAddsBalance() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let categoryRepo = MockCategoryRepository()

            let account = makeAccount(balance: 100)
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            )

            _ = try await useCase.execute(
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

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 150)
        }

        @Test("Transfer does not adjust balance")
        func testTransferDoesNotChangeBalance() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let categoryRepo = MockCategoryRepository()

            let account = makeAccount(balance: 1000)
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            )

            _ = try await useCase.execute(
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

            let updatedAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(updatedAccount?.balance == 1000)
        }

        @Test("Throws validation error for zero amount")
        func testThrowsForZeroAmount() async throws {
            let accountRepo = MockAccountRepository()
            let account = makeAccount()
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo,
                categoryRepository: MockCategoryRepository()
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
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
            let useCase = AddTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: MockAccountRepository(),
                categoryRepository: MockCategoryRepository()
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
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
            let accountRepo = MockAccountRepository()
            let account = makeAccount(isArchived: true)
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo,
                categoryRepository: MockCategoryRepository()
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
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
            let accountRepo = MockAccountRepository()
            let account = makeAccount()
            await accountRepo.seed(account)

            let useCase = AddTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo,
                categoryRepository: MockCategoryRepository()
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
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
            let accountRepo = MockAccountRepository()
            let categoryRepo = MockCategoryRepository()

            let account = makeAccount()
            let category = makeCategory()
            await accountRepo.seed(account)
            await categoryRepo.seed(category)

            let useCase = AddTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo,
                categoryRepository: categoryRepo
            )

            let result = try await useCase.execute(
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
                accountRepository: accountRepo
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
                accountRepository: accountRepo
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
                accountRepository: accountRepo
            )
            try await useCase.executeBulk(ids: [t1.id, t2.id])

            let remaining = await transactionRepo.transactions
            #expect(remaining.isEmpty)
        }

        @Test("Throws when transaction not found")
        func testThrowsWhenTransactionMissing() async throws {
            let useCase = DeleteTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: MockAccountRepository()
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(id: UUID())
            }
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
                accountRepository: accountRepo
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
                accountRepository: accountRepo
            )
            try await useCase.execute(updated)

            // Reverse 300 income (-300 → 1000), apply 500 income (+500 → 1500)
            let finalAccount = accountRepo.accounts.first { $0.id == account.id }
            #expect(finalAccount?.balance == 1500)
        }

        @Test("Throws when transaction does not exist")
        func testThrowsWhenTransactionMissing() async throws {
            let accountRepo = MockAccountRepository()
            let account = AccountEntity(name: "Bank", type: .bank, balance: 1000)
            await accountRepo.seed(account)

            let useCase = UpdateTransactionUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo
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
