import Foundation
import Testing
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

        private func makeUseCase(
            debtRepo: MockDebtRepository,
            txRepo: MockTransactionRepository,
            accountRepo: MockAccountRepository
        ) -> SettleDebtUseCase {
            SettleDebtUseCase(
                debtRepository: debtRepo,
                transactionRepository: txRepo,
                accountRepository: accountRepo
            )
        }

        @Test("partial settlement updates settledAmount")
        @MainActor
        func partialSettlement() async throws {
            let debtRepo = MockDebtRepository()
            let entry = DebtEntry(payeeID: UUID(), amount: 1000, direction: .lent)
            debtRepo.seed(entry)

            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: MockTransactionRepository(), accountRepo: MockAccountRepository())
            try await useCase.execute(debtID: entry.id, settlementAmount: 300, accountID: nil)

            let updated = debtRepo.debts.first { $0.id == entry.id }
            #expect(updated?.settledAmount == 300)
            #expect(updated?.isSettled == false)
        }

        @Test("full settlement marks isSettled true")
        @MainActor
        func fullSettlement() async throws {
            let debtRepo = MockDebtRepository()
            let entry = DebtEntry(payeeID: UUID(), amount: 500, direction: .borrowed)
            debtRepo.seed(entry)

            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: MockTransactionRepository(), accountRepo: MockAccountRepository())
            try await useCase.execute(debtID: entry.id, settlementAmount: 500, accountID: nil)

            let updated = debtRepo.debts.first { $0.id == entry.id }
            #expect(updated?.isSettled == true)
            #expect(updated?.settledAmount == 500)
        }

        @Test("throws notFound for unknown debt ID")
        @MainActor
        func throwsNotFound() async {
            let debtRepo = MockDebtRepository()
            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: MockTransactionRepository(), accountRepo: MockAccountRepository())

            await #expect(throws: VittoraError.self) {
                try await useCase.execute(
                    debtID: UUID(),
                    settlementAmount: 100,
                    accountID: nil
                )
            }
        }

        @Test("throws validationFailed when amount exceeds remaining")
        @MainActor
        func throwsWhenAmountExceedsRemaining() async {
            let debtRepo = MockDebtRepository()
            let entry = DebtEntry(
                payeeID: UUID(),
                amount: 200,
                settledAmount: 150,
                direction: .lent
            )
            debtRepo.seed(entry)

            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: MockTransactionRepository(), accountRepo: MockAccountRepository())
            await #expect(throws: VittoraError.self) {
                try await useCase.execute(
                    debtID: entry.id,
                    settlementAmount: 100, // remaining is only 50
                    accountID: nil
                )
            }
        }

        @Test("throws validationFailed for zero settlement amount")
        @MainActor
        func throwsForZeroAmount() async {
            let debtRepo = MockDebtRepository()
            let entry = DebtEntry(payeeID: UUID(), amount: 100, direction: .lent)
            debtRepo.seed(entry)

            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: MockTransactionRepository(), accountRepo: MockAccountRepository())
            await #expect(throws: VittoraError.self) {
                try await useCase.execute(
                    debtID: entry.id,
                    settlementAmount: 0,
                    accountID: nil
                )
            }
        }

        @Test("settlement with account creates linked transaction")
        @MainActor
        func settlementWithAccountCreatesTransaction() async throws {
            let debtRepo = MockDebtRepository()
            let txRepo = MockTransactionRepository()
            let accountRepo = MockAccountRepository()

            let entry = DebtEntry(payeeID: UUID(), amount: 300, direction: .lent)
            debtRepo.seed(entry)

            let account = AccountEntity(name: "Wallet", type: .cash, balance: 1000)
            try await accountRepo.create(account)

            let useCase = makeUseCase(debtRepo: debtRepo, txRepo: txRepo, accountRepo: accountRepo)
            try await useCase.execute(
                debtID: entry.id,
                settlementAmount: 300,
                accountID: account.id
            )

            let txCount = await txRepo.transactions.count
            #expect(txCount == 1)

            let updatedEntry = debtRepo.debts.first { $0.id == entry.id }
            #expect(updatedEntry?.linkedTransactionID != nil)
            #expect(updatedEntry?.isSettled == true)
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
