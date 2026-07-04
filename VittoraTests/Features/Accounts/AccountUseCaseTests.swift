import Foundation
import Testing
import SwiftData
import VittoraCore

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

        @Test("Persists credit card billing days")
        func testCreatesCreditCardWithBillingDays() async throws {
            let repo = MockAccountRepository()
            let useCase = CreateAccountUseCase(accountRepository: repo)

            try await useCase.execute(
                name: "Visa",
                type: .creditCard,
                balance: 0,
                currencyCode: "USD",
                icon: "creditcard.fill",
                statementDayOfMonth: 5,
                dueDayOfMonth: 20
            )

            let account = try #require(repo.accounts.first)
            #expect(account.statementDayOfMonth == 5)
            #expect(account.dueDayOfMonth == 20)
        }

        @Test("Clears billing days for non-credit-card types")
        func testClearsBillingDaysForNonCreditCard() async throws {
            let repo = MockAccountRepository()
            let useCase = CreateAccountUseCase(accountRepository: repo)

            try await useCase.execute(
                name: "Checking",
                type: .bank,
                balance: 0,
                currencyCode: "USD",
                icon: "building.columns.fill",
                statementDayOfMonth: 5,
                dueDayOfMonth: 20
            )

            let account = try #require(repo.accounts.first)
            #expect(account.statementDayOfMonth == nil)
            #expect(account.dueDayOfMonth == nil)
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

    // A3 (DATAINTEGRITY-1/2): transfers go through a real `LedgerWriteStore`
    // backed by an in-memory container so atomicity and rollback are exercised
    // against the real persistence path, not a mock.
    @MainActor
    @Suite("TransferFundsUseCase")
    struct TransferFundsUseCaseTests {
        private struct Env {
            let accounts: SwiftDataAccountRepository
            let transactions: SwiftDataTransactionRepository
            let store: LedgerWriteStore
            let useCase: TransferFundsUseCase
        }

        private func makeEnv() throws -> Env {
            let container = try ModelContainerConfig.makePreviewContainer()
            let accounts = SwiftDataAccountRepository(modelContainer: container)
            let transactions = SwiftDataTransactionRepository(modelContainer: container)
            let store = LedgerWriteStore(modelContainer: container)
            let useCase = TransferFundsUseCase(accountRepository: accounts, ledgerWriteStore: store)
            return Env(accounts: accounts, transactions: transactions, store: store, useCase: useCase)
        }

        @Test("Moves funds and creates paired debit/credit transfer legs in one save")
        func testTransferUpdatesBalancesAndCreatesTransactions() async throws {
            let env = try makeEnv()
            let checkingID = UUID()
            let savingsID = UUID()
            try await env.accounts.create(
                AccountEntity(id: checkingID, name: "Checking", type: .bank, balance: 1500)
            )
            try await env.accounts.create(
                AccountEntity(id: savingsID, name: "Savings", type: .bank, balance: 500)
            )

            try await env.useCase.execute(
                sourceAccountID: checkingID,
                destinationAccountID: savingsID,
                amount: 125,
                note: "Move to savings"
            )

            let checking = try #require(try await env.accounts.fetchByID(checkingID))
            let savings = try #require(try await env.accounts.fetchByID(savingsID))
            #expect(checking.balance == 1375)
            #expect(savings.balance == 625)

            let legs = try await env.transactions.fetchAll(filter: nil)
            #expect(legs.count == 2)
            #expect(legs.allSatisfy { $0.type == .transfer })
            // Both legs share one pair id.
            let pairIDs = Set(legs.compactMap { $0.transferPairID })
            #expect(pairIDs.count == 1)
            // One debit on source, one credit on destination.
            let debit = try #require(legs.first { $0.transferDirection == .debit })
            let credit = try #require(legs.first { $0.transferDirection == .credit })
            #expect(debit.accountID == checkingID)
            #expect(credit.accountID == savingsID)
            // Exactly one save persisted the whole compound operation.
            #expect(await env.store.saveCount == 1)
        }

        @Test("Transfer is balance-neutral: total balances and signed leg effects net to zero")
        func transferIsBalanceNeutral() async throws {
            let env = try makeEnv()
            let aID = UUID()
            let bID = UUID()
            try await env.accounts.create(AccountEntity(id: aID, name: "A", type: .bank, balance: 1000))
            try await env.accounts.create(AccountEntity(id: bID, name: "B", type: .bank, balance: 200))

            let before = try await env.accounts.fetchAll().reduce(Decimal(0)) { $0 + $1.balance }
            try await env.useCase.execute(sourceAccountID: aID, destinationAccountID: bID, amount: 300)
            let after = try await env.accounts.fetchAll().reduce(Decimal(0)) { $0 + $1.balance }
            #expect(after == before)

            // The two legs' canonical signed effects cancel out.
            let legs = try await env.transactions.fetchAll(filter: nil)
            let signedSum = legs.reduce(Decimal(0)) { $0 + $1.signedBalanceEffect }
            #expect(signedSum == 0)
        }

        @Test("Partial failure (missing destination) rolls back: no legs, no balance change, no save")
        func transferRollsBackOnPartialFailure() async throws {
            let env = try makeEnv()
            let sourceID = UUID()
            try await env.accounts.create(
                AccountEntity(id: sourceID, name: "Source", type: .bank, balance: 1000)
            )

            // Genuine in-op failure: destination id does not exist, so the store
            // throws mid-commit and rolls back the already-inserted debit leg and
            // the source balance change.
            await #expect(throws: (any Error).self) {
                try await env.store.performTransfer(
                    sourceAccountID: sourceID,
                    destinationAccountID: UUID(),
                    amount: 250,
                    date: .now,
                    note: "",
                    currencyCode: CurrencyDefaults.code
                )
            }

            let source = try #require(try await env.accounts.fetchByID(sourceID))
            #expect(source.balance == 1000)
            let legs = try await env.transactions.fetchAll(filter: nil)
            #expect(legs.isEmpty)
            #expect(await env.store.saveCount == 0)
        }

        @Test("Rejects transfers between the same account")
        func testTransferRejectsSameAccount() async throws {
            let env = try makeEnv()
            let accountID = UUID()
            try await env.accounts.create(
                AccountEntity(id: accountID, name: "Checking", type: .bank, balance: 1000)
            )

            await #expect(throws: (any Error).self) {
                try await env.useCase.execute(
                    sourceAccountID: accountID,
                    destinationAccountID: accountID,
                    amount: 50
                )
            }
        }
    }

    // MARK: - UpdateTransferUseCase (A4)

    // A4 (DATAINTEGRITY-1): dedicated transfer-edit flow — reverses both old legs
    // and re-applies both new legs atomically via the real `LedgerWriteStore`.
    @MainActor
    @Suite("UpdateTransferUseCase")
    struct UpdateTransferUseCaseTests {
        private struct Env {
            let accounts: SwiftDataAccountRepository
            let transactions: SwiftDataTransactionRepository
            let store: LedgerWriteStore
            let transfer: TransferFundsUseCase
            let updateTransfer: UpdateTransferUseCase
        }

        private func makeEnv() throws -> Env {
            let container = try ModelContainerConfig.makePreviewContainer()
            let accounts = SwiftDataAccountRepository(modelContainer: container)
            let transactions = SwiftDataTransactionRepository(modelContainer: container)
            let store = LedgerWriteStore(modelContainer: container)
            return Env(
                accounts: accounts,
                transactions: transactions,
                store: store,
                transfer: TransferFundsUseCase(accountRepository: accounts, ledgerWriteStore: store),
                updateTransfer: UpdateTransferUseCase(accountRepository: accounts, ledgerWriting: store)
            )
        }

        @Test("Editing a transfer's amount reverses both old legs and applies both new legs")
        func editAmountReversesAndReapplies() async throws {
            let env = try makeEnv()
            let aID = UUID()
            let bID = UUID()
            try await env.accounts.create(AccountEntity(id: aID, name: "A", type: .bank, balance: 1000))
            try await env.accounts.create(AccountEntity(id: bID, name: "B", type: .bank, balance: 0))

            try await env.transfer.execute(sourceAccountID: aID, destinationAccountID: bID, amount: 250)
            let pairID = try #require(
                try await env.transactions.fetchAll(filter: nil).compactMap { $0.transferPairID }.first
            )

            try await env.updateTransfer.execute(
                transferPairID: pairID,
                sourceAccountID: aID,
                destinationAccountID: bID,
                amount: 400
            )

            let a = try #require(try await env.accounts.fetchByID(aID))
            let b = try #require(try await env.accounts.fetchByID(bID))
            #expect(a.balance == 600)
            #expect(b.balance == 400)
            let legs = try await env.transactions.fetchAll(filter: nil)
            #expect(legs.count == 2)
            #expect(legs.allSatisfy { $0.amount == 400 })
        }

        @Test("Rejects editing a transfer onto the same account")
        func rejectsSameAccount() async throws {
            let env = try makeEnv()
            let aID = UUID()
            let bID = UUID()
            try await env.accounts.create(AccountEntity(id: aID, name: "A", type: .bank, balance: 1000))
            try await env.accounts.create(AccountEntity(id: bID, name: "B", type: .bank, balance: 0))
            try await env.transfer.execute(sourceAccountID: aID, destinationAccountID: bID, amount: 100)
            let pairID = try #require(
                try await env.transactions.fetchAll(filter: nil).compactMap { $0.transferPairID }.first
            )

            await #expect(throws: (any Error).self) {
                try await env.updateTransfer.execute(
                    transferPairID: pairID,
                    sourceAccountID: aID,
                    destinationAccountID: aID,
                    amount: 100
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
