import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// The opening balance a new account starts with.
///
/// Found by creating an account in the Mac app: the field defaulted to the
/// string "0" while also showing a 0.00 placeholder, and the text is
/// right-aligned. Clicking into it and typing 1500 produced 15000 — the typed
/// digits landed beside the zero already there. A silent tenfold error on the
/// opening balance of a real account, which then flows into net worth and
/// every balance derived from it.
///
/// The zero was only there to satisfy `canSave`, so these pin the empty case
/// instead: blank means zero, and a typed amount is exactly what was typed.
@Suite("New account opening balance")
@MainActor
struct AccountFormBalanceTests {

    private func makeVM() -> (AccountFormViewModel, MockAccountRepository) {
        let repo = MockAccountRepository()
        let vm = AccountFormViewModel(
            createUseCase: CreateAccountUseCase(accountRepository: repo),
            updateUseCase: UpdateAccountUseCase(accountRepository: repo),
            repository: repo
        )
        return (vm, repo)
    }

    @Test("the field starts empty so typed digits are not appended to a zero")
    func startsEmpty() {
        let (vm, _) = makeVM()
        #expect(vm.initialBalance.isEmpty)
    }

    @Test("a named account can be saved without touching the balance")
    func blankBalanceIsSaveable() {
        let (vm, _) = makeVM()
        vm.name = "Test Savings"
        #expect(vm.canSave)
    }

    @Test("a blank balance is stored as zero, not rejected")
    func blankBalanceMeansZero() async throws {
        let (vm, repo) = makeVM()
        vm.name = "Test Savings"
        try await vm.save()

        let saved = try #require(try await repo.fetchAll().first)
        #expect(saved.balance == 0)
    }

    @Test("a typed amount is stored exactly as typed")
    func typedAmountIsExact() async throws {
        let (vm, repo) = makeVM()
        vm.name = "Test Savings"
        vm.initialBalance = "1500"
        try await vm.save()

        let saved = try #require(try await repo.fetchAll().first)
        // The bug produced 15000 here.
        #expect(saved.balance == Decimal(string: "1500")!)
    }

    @Test("a balance that is not a number is still rejected")
    func nonsenseIsStillRejected() {
        let (vm, _) = makeVM()
        vm.name = "Test Savings"
        vm.initialBalance = "abc"
        #expect(!vm.canSave)
    }
}
