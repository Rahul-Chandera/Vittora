import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Debt Use Case Tests")
struct DebtUseCaseTests {

    // MARK: - CreateDebtEntryUseCase

    @Suite("CreateDebtEntryUseCase")
    @MainActor
    struct CreateDebtEntryUseCaseTests {

        @Test("creates entry and returns it")
        func createsEntry() async throws {
            let repo = MockDebtRepository()
            let payeeID = UUID()
            let useCase = CreateDebtEntryUseCase(debtRepository: repo)

            let result = try await useCase.execute(
                payeeID: payeeID,
                amount: 500,
                direction: .lent,
                dueDate: nil,
                note: "Birthday loan"
            )

            #expect(result.payeeID == payeeID)
            #expect(result.amount == 500)
            #expect(result.direction == .lent)
            #expect(result.note == "Birthday loan")
            #expect(result.isSettled == false)
            #expect(repo.debts.count == 1)
        }

        @Test("throws validationFailed for zero amount")
        func throwsForZeroAmount() async {
            let repo = MockDebtRepository()
            let useCase = CreateDebtEntryUseCase(debtRepository: repo)

            await #expect(throws: VittoraError.self) {
                try await useCase.execute(
                    payeeID: UUID(),
                    amount: 0,
                    direction: .borrowed
                )
            }
            #expect(repo.debts.isEmpty)
        }

        @Test("throws validationFailed for negative amount")
        func throwsForNegativeAmount() async {
            let repo = MockDebtRepository()
            let useCase = CreateDebtEntryUseCase(debtRepository: repo)

            await #expect(throws: VittoraError.self) {
                try await useCase.execute(
                    payeeID: UUID(),
                    amount: -100,
                    direction: .lent
                )
            }
        }
    }

    // MARK: - SettleDebtUseCase

    @Suite("SettleDebtUseCase")
    @MainActor
    struct SettleDebtUseCaseTests {

        // A6: settlement writes through a real LedgerWriteStore so the debt
        // bump, the linked transaction, and the balance change land in one
        // save. Tests run against one in-memory container end-to-end.
        private struct Env {
            let debtRepo: SwiftDataDebtRepository
            let accountRepo: SwiftDataAccountRepository
            let txRepo: SwiftDataTransactionRepository
            let useCase: SettleDebtUseCase
        }

        private func makeEnv() throws -> Env {
            let container = try ModelContainerConfig.makeContainer(inMemory: true)
            let debtRepo = SwiftDataDebtRepository(modelContainer: container)
            let accountRepo = SwiftDataAccountRepository(modelContainer: container)
            let txRepo = SwiftDataTransactionRepository(modelContainer: container)
            let store = LedgerWriteStore(modelContainer: container)
            let useCase = SettleDebtUseCase(
                debtRepository: debtRepo,
                accountRepository: accountRepo,
                ledgerWriting: store
            )
            return Env(debtRepo: debtRepo, accountRepo: accountRepo, txRepo: txRepo, useCase: useCase)
        }

        @Test("partial settlement updates settledAmount")
        @MainActor
        func partialSettlement() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(payeeID: UUID(), amount: 1000, direction: .lent)
            try await env.debtRepo.create(entry)

            try await env.useCase.execute(debtID: entry.id, settlementAmount: 300, accountID: nil)

            let updated = try await env.debtRepo.fetchByID(entry.id)
            #expect(updated?.settledAmount == 300)
            #expect(updated?.isSettled == false)
        }

        @Test("full settlement marks isSettled true")
        @MainActor
        func fullSettlement() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(payeeID: UUID(), amount: 500, direction: .borrowed)
            try await env.debtRepo.create(entry)

            try await env.useCase.execute(debtID: entry.id, settlementAmount: 500, accountID: nil)

            let updated = try await env.debtRepo.fetchByID(entry.id)
            #expect(updated?.isSettled == true)
            #expect(updated?.settledAmount == 500)
        }

        @Test("throws notFound for unknown debt ID")
        @MainActor
        func throwsNotFound() async throws {
            let env = try makeEnv()

            await #expect(throws: VittoraError.self) {
                try await env.useCase.execute(
                    debtID: UUID(),
                    settlementAmount: 100,
                    accountID: nil
                )
            }
        }

        @Test("throws validationFailed when amount exceeds remaining")
        @MainActor
        func throwsWhenAmountExceedsRemaining() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(
                payeeID: UUID(),
                amount: 200,
                settledAmount: 150,
                direction: .lent
            )
            try await env.debtRepo.create(entry)

            await #expect(throws: VittoraError.self) {
                try await env.useCase.execute(
                    debtID: entry.id,
                    settlementAmount: 100, // remaining is only 50
                    accountID: nil
                )
            }
        }

        @Test("throws validationFailed for zero settlement amount")
        @MainActor
        func throwsForZeroAmount() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(payeeID: UUID(), amount: 100, direction: .lent)
            try await env.debtRepo.create(entry)

            await #expect(throws: VittoraError.self) {
                try await env.useCase.execute(
                    debtID: entry.id,
                    settlementAmount: 0,
                    accountID: nil
                )
            }
        }

        @Test("settlement with account creates linked transaction and moves balance")
        @MainActor
        func settlementWithAccountCreatesTransaction() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(payeeID: UUID(), amount: 300, direction: .lent)
            try await env.debtRepo.create(entry)

            let account = AccountEntity(name: "Wallet", type: .cash, balance: 1000)
            try await env.accountRepo.create(account)

            try await env.useCase.execute(
                debtID: entry.id,
                settlementAmount: 300,
                accountID: account.id
            )

            let savedTransactions = try await env.txRepo.fetchAll(filter: nil)
            #expect(savedTransactions.count == 1)

            let updatedEntry = try await env.debtRepo.fetchByID(entry.id)
            #expect(updatedEntry?.linkedTransactionIDs.count == 1)
            #expect(updatedEntry?.isSettled == true)

            // Lent debt repaid -> income -> account balance increases.
            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 1300)
        }

        @Test("two partial settlements retain both linked transactions")
        @MainActor
        func twoPartialSettlementsRetained() async throws {
            let env = try makeEnv()
            let entry = DebtEntry(payeeID: UUID(), amount: 1000, direction: .lent)
            try await env.debtRepo.create(entry)

            let account = AccountEntity(name: "Wallet", type: .cash, balance: 1000)
            try await env.accountRepo.create(account)

            try await env.useCase.execute(
                debtID: entry.id,
                settlementAmount: 300,
                accountID: account.id
            )
            try await env.useCase.execute(
                debtID: entry.id,
                settlementAmount: 200,
                accountID: account.id
            )

            let savedTransactions = try await env.txRepo.fetchAll(filter: nil)
            #expect(savedTransactions.count == 2)

            let updatedEntry = try await env.debtRepo.fetchByID(entry.id)
            #expect(updatedEntry?.settledAmount == 500)
            #expect(updatedEntry?.linkedTransactionIDs.count == 2)
            #expect(Set(updatedEntry?.linkedTransactionIDs ?? []) == Set(savedTransactions.map(\.id)))
            #expect(updatedEntry?.isSettled == false)

            let updatedAccount = try await env.accountRepo.fetchByID(account.id)
            #expect(updatedAccount?.balance == 1500)
        }
    }

    // MARK: - FetchDebtLedgerUseCase

    @Suite("FetchDebtLedgerUseCase")
    @MainActor
    struct FetchDebtLedgerUseCaseTests {

        @Test("returns empty ledger when no outstanding debts")
        func emptyLedger() async throws {
            let debtRepo = MockDebtRepository()
            let payeeRepo = MockPayeeRepository()
            let useCase = FetchDebtLedgerUseCase(debtRepository: debtRepo, payeeRepository: payeeRepo)

            let result = try await useCase.execute()
            #expect(result.isEmpty)
        }

        @Test("groups outstanding debts by payee")
        func groupsByPayee() async throws {
            let debtRepo = MockDebtRepository()
            let payeeRepo = MockPayeeRepository()

            let payee = PayeeEntity(name: "Alice")
            await payeeRepo.seed(payee)

            let debt1 = DebtEntry(payeeID: payee.id, amount: 500, direction: .lent)
            let debt2 = DebtEntry(payeeID: payee.id, amount: 200, direction: .lent)
            debtRepo.seed(debt1)
            debtRepo.seed(debt2)

            let useCase = FetchDebtLedgerUseCase(debtRepository: debtRepo, payeeRepository: payeeRepo)
            let result = try await useCase.execute()

            #expect(result.count == 1)
            #expect(result.first?.payee.id == payee.id)
            #expect(result.first?.totalLent == 700)
            #expect(result.first?.totalBorrowed == 0)
        }

        @Test("excludes settled debts from ledger")
        func excludesSettledDebts() async throws {
            let debtRepo = MockDebtRepository()
            let payeeRepo = MockPayeeRepository()

            let payee = PayeeEntity(name: "Bob")
            await payeeRepo.seed(payee)

            let outstanding = DebtEntry(payeeID: payee.id, amount: 100, direction: .borrowed)
            let settled = DebtEntry(payeeID: payee.id, amount: 200, direction: .lent, isSettled: true)
            debtRepo.seed(outstanding)
            debtRepo.seed(settled)

            let useCase = FetchDebtLedgerUseCase(debtRepository: debtRepo, payeeRepository: payeeRepo)
            let result = try await useCase.execute()

            #expect(result.count == 1)
            #expect(result.first?.totalBorrowed == 100)
            #expect(result.first?.totalLent == 0)
        }
    }
}
