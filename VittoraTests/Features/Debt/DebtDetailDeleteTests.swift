import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Deleting a debt entry.
///
/// There was no way to remove one from the UI at all: the repository has always
/// had `delete(_:)`, but nothing called it, so an entry logged by mistake was
/// permanent. Deletion of money records is covered by the house rule requiring
/// targeted tests, so the behaviour is pinned here.
///
/// Deleting is deliberately not settling. Settling records that the money moved
/// and keeps the row; deleting erases the entry, and must not invent a
/// settlement or touch the other party's remaining entries.
@Suite("Debt entry deletion")
@MainActor
struct DebtDetailDeleteTests {

    private struct Env {
        let vm: DebtDetailViewModel
        let debtRepo: MockDebtRepository
        let payeeID: UUID
        let lent: DebtEntry
        let borrowed: DebtEntry
    }

    private func makeEnv() async throws -> Env {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let debtRepo = MockDebtRepository()
        let payeeRepo = MockPayeeRepository()

        let payee = PayeeEntity(name: "Raj")
        try await payeeRepo.create(payee)

        let lent = DebtEntry(
            payeeID: payee.id, amount: Decimal(string: "5000")!, direction: .lent)
        let borrowed = DebtEntry(
            payeeID: payee.id, amount: Decimal(string: "1200")!, direction: .borrowed)
        try await debtRepo.create(lent)
        try await debtRepo.create(borrowed)

        let vm = DebtDetailViewModel(
            payeeID: payee.id,
            debtRepository: debtRepo,
            payeeRepository: payeeRepo,
            settleUseCase: SettleDebtUseCase(
                debtRepository: debtRepo,
                accountRepository: MockAccountRepository(),
                ledgerWriting: LedgerWriteStore(modelContainer: container)
            )
        )
        await vm.load()
        return Env(vm: vm, debtRepo: debtRepo, payeeID: payee.id, lent: lent, borrowed: borrowed)
    }

    @Test("deleting an entry removes it and leaves the others alone")
    func deleteRemovesOnlyThatEntry() async throws {
        let env = try await makeEnv()
        #expect(env.vm.entries.count == 2)

        await env.vm.delete(debtID: env.lent.id)

        #expect(env.vm.error == nil)
        #expect(env.vm.entries.map(\.id) == [env.borrowed.id])
        // Gone from storage, not merely filtered out of the view model.
        #expect(try await env.debtRepo.fetchByID(env.lent.id) == nil)
    }

    @Test("the deleted amount stops counting toward the balance")
    func deleteUpdatesBalance() async throws {
        let env = try await makeEnv()
        #expect(env.vm.totalLent == Decimal(string: "5000")!)
        #expect(env.vm.netBalance == Decimal(string: "3800")!)

        await env.vm.delete(debtID: env.lent.id)

        #expect(env.vm.totalLent == 0)
        #expect(env.vm.totalBorrowed == Decimal(string: "1200")!)
        #expect(env.vm.netBalance == Decimal(string: "-1200")!)
    }

    @Test("deleting does not mark the entry settled")
    func deleteIsNotSettlement() async throws {
        let env = try await makeEnv()
        await env.vm.delete(debtID: env.lent.id)

        // A settled entry would still be fetchable with isSettled true. Deletion
        // must erase it instead, or the ledger would show phantom repayments.
        let all = try await env.debtRepo.fetchAll()
        #expect(all.count == 1)
        #expect(all.allSatisfy { !$0.isSettled })
    }

    @Test("a failed delete surfaces an error and keeps the entry")
    func deleteFailureIsReported() async throws {
        let env = try await makeEnv()
        env.debtRepo.shouldThrowError = true

        await env.vm.delete(debtID: env.lent.id)

        #expect(env.vm.error != nil)
        env.debtRepo.shouldThrowError = false
        #expect(try await env.debtRepo.fetchByID(env.lent.id) != nil)
    }
}
