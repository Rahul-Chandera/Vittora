import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Account Use Case Tests")
struct AccountUseCaseTests {

    // MARK: - FetchAccountsUseCase

    @MainActor
    @Suite("FetchAccountsUseCase")
    struct FetchAccountsUseCaseTests {
        @Test("Execute filters out archived accounts")
        func testExecuteFiltersArchivedAccounts() async throws {
            let repo = MockAccountRepository()
            await repo.seed(AccountEntity(name: "Active", type: .bank, isArchived: false))
            await repo.seed(AccountEntity(name: "Archived", type: .bank, isArchived: true))

            let useCase = FetchAccountsUseCase(accountRepository: repo)
            let result = try await useCase.execute()

            #expect(result.count == 1)
            #expect(result[0].name == "Active")
        }

        @Test("ExecuteGroupedByType groups accounts correctly")
        func testExecuteGroupedByType() async throws {
            let repo = MockAccountRepository()
            await repo.seed(AccountEntity(name: "Chase", type: .bank))
            await repo.seed(AccountEntity(name: "Cash", type: .cash))
            await repo.seed(AccountEntity(name: "Wells Fargo", type: .bank))

            let useCase = FetchAccountsUseCase(accountRepository: repo)
            let grouped = try await useCase.executeGroupedByType()

            #expect(grouped[.bank]?.count == 2)
            #expect(grouped[.cash]?.count == 1)
        }
    }

    // MARK: - CalculateNetWorthUseCase

    @MainActor
    @Suite("CalculateNetWorthUseCase")
    struct CalculateNetWorthUseCaseTests {
        @Test("Calculates net worth from assets and liabilities")
        func testCalculatesNetWorth() async throws {
            let repo = MockAccountRepository()
            await repo.seed(AccountEntity(name: "Checking", type: .bank, balance: Decimal(5000)))
            await repo.seed(AccountEntity(name: "Savings", type: .bank, balance: Decimal(10000)))
            await repo.seed(AccountEntity(name: "Visa", type: .creditCard, balance: Decimal(2000)))

            let useCase = CalculateNetWorthUseCase(accountRepository: repo)
            let summary = try await useCase.execute()

            #expect(summary.totalAssets == Decimal(15000))
            #expect(summary.totalLiabilities == Decimal(2000))
            #expect(summary.netWorth == Decimal(13000))
        }

        @Test("Net worth is zero when no accounts")
        func testZeroNetWorthWithNoAccounts() async throws {
            let repo = MockAccountRepository()
            let useCase = CalculateNetWorthUseCase(accountRepository: repo)
            let summary = try await useCase.execute()

            #expect(summary.netWorth == 0)
            #expect(summary.totalAssets == 0)
            #expect(summary.totalLiabilities == 0)
        }
    }

    // MARK: - CreateAccountUseCase

    @MainActor
    @Suite("CreateAccountUseCase")
    struct CreateAccountUseCaseTests {
        @Test("Creates a bank account with correct fields")
        func testCreatesBankAccount() async throws {
            let repo = MockAccountRepository()
            let useCase = CreateAccountUseCase(accountRepository: repo)

            try await useCase.execute(
                name: "Chase Checking",
                type: .bank,
                balance: Decimal(1000),
                currencyCode: "USD",
                icon: "building.columns.fill"
            )

            let all = repo.accounts
            #expect(all.count == 1)
            #expect(all[0].name == "Chase Checking")
            #expect(all[0].type == .bank)
            #expect(all[0].balance == Decimal(1000))
        }

        @Test("Throws validation error for empty name")
        func testThrowsForEmptyName() async throws {
            let repo = MockAccountRepository()
            let useCase = CreateAccountUseCase(accountRepository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
                    name: "",
                    type: .bank,
                    balance: 0,
                    currencyCode: "USD",
                    icon: "building.columns.fill"
                )
            }
        }
    }

    // MARK: - TransferFundsUseCase

    @MainActor
    @Suite("TransferFundsUseCase")
    struct TransferFundsUseCaseTests {
        @Test("Moves funds between accounts and creates paired transfer transactions")
        func testTransferUpdatesBalancesAndCreatesTransactions() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let checkingAccount = AccountEntity(name: "Checking", type: .bank, balance: Decimal(1500))
            let savingsAccount = AccountEntity(name: "Savings", type: .bank, balance: Decimal(500))
            await accountRepo.seed(checkingAccount)
            await accountRepo.seed(savingsAccount)

            let useCase = TransferFundsUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo
            )

            try await useCase.execute(
                sourceAccountID: checkingAccount.id,
                destinationAccountID: savingsAccount.id,
                amount: Decimal(125),
                note: "Move to savings"
            )

            let updatedCheckingAccount = accountRepo.accounts.first { $0.id == checkingAccount.id }
            let updatedSavingsAccount = accountRepo.accounts.first { $0.id == savingsAccount.id }
            let savedTransactions = await transactionRepo.transactions

            #expect(updatedCheckingAccount?.balance == Decimal(1375))
            #expect(updatedSavingsAccount?.balance == Decimal(625))
            #expect(savedTransactions.count == 2)
            #expect(savedTransactions.allSatisfy { $0.type == .transfer })
        }

        @Test("Rejects transfers between the same account")
        func testTransferRejectsSameAccount() async throws {
            let accountRepo = MockAccountRepository()
            let account = AccountEntity(name: "Checking", type: .bank, balance: Decimal(1000))
            await accountRepo.seed(account)

            let useCase = TransferFundsUseCase(
                transactionRepository: MockTransactionRepository(),
                accountRepository: accountRepo
            )

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
                    sourceAccountID: account.id,
                    destinationAccountID: account.id,
                    amount: Decimal(50)
                )
            }
        }
    }

    // MARK: - DeleteAccountUseCase

    @MainActor
    @Suite("DeleteAccountUseCase")
    struct DeleteAccountUseCaseTests {
        @Test("Archives an account successfully")
        func testArchivesAccount() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()
            let account = AccountEntity(name: "Old Account", type: .bank)
            await accountRepo.seed(account)

            let useCase = DeleteAccountUseCase(
                accountRepository: accountRepo,
                transactionRepository: transactionRepo
            )
            try await useCase.archive(id: account.id)

            let updated = accountRepo.accounts.first { $0.id == account.id }
            #expect(updated?.isArchived == true)
        }

        @Test("Throws when account not found during archive")
        func testThrowsForNonExistentAccountOnArchive() async throws {
            let accountRepo = MockAccountRepository()
            let transactionRepo = MockTransactionRepository()

            let useCase = DeleteAccountUseCase(
                accountRepository: accountRepo,
                transactionRepository: transactionRepo
            )

            await #expect(throws: (any Error).self) {
                try await useCase.archive(id: UUID())
            }
        }
    }
}

// MARK: - Seed helpers for MockAccountRepository
extension MockAccountRepository {
    func seed(_ entity: AccountEntity) async {
        try? await create(entity)
    }
}
