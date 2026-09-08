import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Deleting a group expense.
///
/// Found while sweeping the screens that had not been exercised by hand: the
/// expense rows on the split group detail screen live in a ScrollView, and
/// `.swipeActions` only fires inside a List. There was no context menu and no
/// detail screen, so deleting — and settling — a group expense had no reachable
/// path on either platform. The actions existed and could not be invoked.
///
/// A group expense is a money record shared between people, so removing one has
/// to move everyone's balance with it. That recalculation is what these pin;
/// the repository's own delete is covered by SwiftDataSplitGroupRepositoryTests.
@Suite("Group expense deletion")
@MainActor
struct SplitGroupExpenseDeleteTests {

    private struct Env {
        let vm: SplitGroupDetailViewModel
        let repo: MockSplitGroupRepository
        let alice: UUID
        let bob: UUID
        let dinner: GroupExpense
        let taxi: GroupExpense
    }

    private func makeEnv() async throws -> Env {
        let repo = MockSplitGroupRepository()
        let payeeRepo = MockPayeeRepository()

        let alice = PayeeEntity(name: "Alice")
        let bob = PayeeEntity(name: "Bob")
        try await payeeRepo.create(alice)
        try await payeeRepo.create(bob)

        let group = SplitGroup(name: "Trip", memberIDs: [alice.id, bob.id])
        repo.seedGroup(group)

        // Alice pays for both, so Bob owes her half of each.
        let dinner = GroupExpense(
            groupID: group.id,
            paidByMemberID: alice.id,
            amount: Decimal(string: "100")!,
            title: "Dinner",
            shares: [
                SplitShare(memberID: alice.id, amount: Decimal(string: "50")!),
                SplitShare(memberID: bob.id, amount: Decimal(string: "50")!)
            ]
        )
        let taxi = GroupExpense(
            groupID: group.id,
            paidByMemberID: alice.id,
            amount: Decimal(string: "40")!,
            title: "Taxi",
            shares: [
                SplitShare(memberID: alice.id, amount: Decimal(string: "20")!),
                SplitShare(memberID: bob.id, amount: Decimal(string: "20")!)
            ]
        )
        repo.seedExpense(dinner)
        repo.seedExpense(taxi)

        let vm = SplitGroupDetailViewModel(
            group: group,
            splitGroupRepository: repo,
            payeeRepository: payeeRepo
        )
        await vm.load()
        return Env(vm: vm, repo: repo, alice: alice.id, bob: bob.id, dinner: dinner, taxi: taxi)
    }

    @Test("deleting an expense removes it and leaves the others alone")
    func deleteRemovesOnlyThatExpense() async throws {
        let env = try await makeEnv()
        #expect(env.vm.expenses.count == 2)

        await env.vm.deleteExpense(env.dinner.id)

        #expect(env.vm.error == nil)
        #expect(env.vm.expenses.map(\.id) == [env.taxi.id])
        // Gone from storage, not merely filtered out of the view model.
        #expect(try await env.repo.fetchExpenseByID(env.dinner.id) == nil)
    }

    @Test("the deleted amount stops counting toward what members owe")
    func deleteRecalculatesBalances() async throws {
        let env = try await makeEnv()
        // Bob owes Alice 50 + 20.
        #expect(env.vm.simplifiedBalances.count == 1)
        #expect(env.vm.simplifiedBalances.first?.amount == Decimal(string: "70")!)

        await env.vm.deleteExpense(env.dinner.id)

        // Only the taxi's 20 remains. Without the recalculation the screen
        // would keep showing a debt for money that is no longer recorded.
        #expect(env.vm.simplifiedBalances.first?.amount == Decimal(string: "20")!)
        #expect(env.vm.simplifiedBalances.first?.fromMemberID == env.bob)
        #expect(env.vm.simplifiedBalances.first?.toMemberID == env.alice)
    }

    @Test("deleting the last outstanding expense clears the balances")
    func deletingEverythingSettlesTheGroup() async throws {
        let env = try await makeEnv()
        await env.vm.deleteExpense(env.dinner.id)
        await env.vm.deleteExpense(env.taxi.id)

        #expect(env.vm.expenses.isEmpty)
        #expect(env.vm.simplifiedBalances.isEmpty)
    }

    @Test("a failed delete surfaces an error and keeps the expense")
    func deleteFailureIsReported() async throws {
        let env = try await makeEnv()
        env.repo.shouldThrowError = true

        await env.vm.deleteExpense(env.dinner.id)

        #expect(env.vm.error != nil)
        env.repo.shouldThrowError = false
        #expect(try await env.repo.fetchExpenseByID(env.dinner.id) != nil)
        // The row must not vanish from the screen when the delete did not happen.
        #expect(env.vm.expenses.count == 2)
    }
}
