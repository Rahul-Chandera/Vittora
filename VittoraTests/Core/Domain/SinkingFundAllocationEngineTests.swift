import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Sinking funds — several goals sharing one account (M2.5.5).
///
/// The behaviour these pin is the one the app could not previously express:
/// goals carried a linkedAccountID that nothing ever read back, so their claims
/// could exceed the money actually in the account and every goal still showed as
/// on track.
@Suite("SinkingFundAllocationEngine")
@MainActor
struct SinkingFundAllocationEngineTests {

    private let engine = SinkingFundAllocationEngine()

    private func d(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    private func account(_ id: UUID, name: String = "Savings", balance: Decimal) -> AccountEntity {
        AccountEntity(id: id, name: name, type: .bank, balance: balance, currencyCode: "GBP")
    }

    private func goal(
        name: String,
        saved: Decimal,
        target: Decimal = 1_000,
        account accountID: UUID?,
        emergency: Bool = false,
        status: GoalStatus = .active
    ) -> SavingsGoalEntity {
        SavingsGoalEntity(
            name: name,
            targetAmount: target,
            currentAmount: saved,
            linkedAccountID: accountID,
            status: status,
            isEmergencyFund: emergency
        )
    }

    // MARK: - The core problem

    /// Three goals each claiming £600 of a £1,000 account. Before this engine
    /// every one of them showed as on track and nothing noticed the £800 that
    /// does not exist.
    @Test("goals claiming more than the account holds are reported as over-allocated")
    func overAllocationDetected() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Car", saved: 600, account: id),
                goal(name: "Holiday", saved: 600, account: id),
                goal(name: "Boiler", saved: 600, account: id),
            ],
            accounts: [account(id, balance: 1_000)]
        )

        let first = try? #require(allocations.first)
        #expect(allocations.count == 1)
        #expect(first?.totalAllocated == 1_800)
        #expect(first?.accountBalance == 1_000)
        #expect(first?.unallocated == -800)
        #expect(first?.isOverAllocated == true)
        #expect(first?.overAllocationAmount == 800)
    }

    @Test("an account with room to spare reports what is unallocated")
    func unallocatedRemainder() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Car", saved: 300, account: id),
                goal(name: "Holiday", saved: 200, account: id),
            ],
            accounts: [account(id, balance: 1_000)]
        )
        #expect(allocations.first?.totalAllocated == 500)
        #expect(allocations.first?.unallocated == 500)
        #expect(allocations.first?.isOverAllocated == false)
        #expect(allocations.first?.overAllocationAmount == 0)
    }

    /// Claiming exactly the balance is not over-allocated.
    @Test("claiming exactly the balance is not over-allocated")
    func exactBoundary() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [goal(name: "Car", saved: 1_000, account: id)],
            accounts: [account(id, balance: 1_000)]
        )
        #expect(allocations.first?.unallocated == 0)
        #expect(allocations.first?.isOverAllocated == false)
    }

    /// A completed goal still holds its money, so it still counts. Dropping it
    /// would make an over-allocated account look healthy the moment one goal
    /// finished — the opposite of what the user needs to see.
    @Test("achieved goals still count against the balance")
    func achievedGoalsStillCount() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Done", saved: 900, target: 900, account: id, status: .achieved),
                goal(name: "Car", saved: 600, account: id),
            ],
            accounts: [account(id, balance: 1_000)]
        )
        #expect(allocations.first?.totalAllocated == 1_500)
        #expect(allocations.first?.isOverAllocated == true)
    }

    // MARK: - Scoping

    /// Goals with no linked account are tracked elsewhere but cannot over-claim
    /// a specific balance, so they are out of scope here.
    @Test("goals with no linked account are excluded")
    func unlinkedGoalsExcluded() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Linked", saved: 100, account: id),
                goal(name: "Floating", saved: 5_000, account: nil),
            ],
            accounts: [account(id, balance: 1_000)]
        )
        #expect(allocations.count == 1)
        #expect(allocations.first?.totalAllocated == 100)
    }

    /// Accounts with nothing earmarked are omitted — this screen is about money
    /// that has been claimed, and listing every empty account buries the rest.
    @Test("accounts with no goals are omitted")
    func emptyAccountsOmitted() {
        let used = UUID()
        let unused = UUID()
        let allocations = engine.allocations(
            goals: [goal(name: "Car", saved: 100, account: used)],
            accounts: [account(used, balance: 500), account(unused, name: "Current", balance: 9_000)]
        )
        #expect(allocations.count == 1)
        #expect(allocations.first?.accountID == used)
    }

    /// A goal pointing at an account that no longer exists must not crash or
    /// invent an allocation.
    @Test("a goal linked to a deleted account is skipped")
    func danglingLinkSkipped() {
        let allocations = engine.allocations(
            goals: [goal(name: "Orphan", saved: 100, account: UUID())],
            accounts: []
        )
        #expect(allocations.isEmpty)
    }

    // MARK: - Ordering and presentation

    @Test("over-allocated accounts are listed first")
    func overAllocatedFirst() {
        let healthy = UUID()
        let broken = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Fine", saved: 100, account: healthy),
                goal(name: "Too much", saved: 5_000, account: broken),
            ],
            accounts: [
                account(healthy, name: "AAA Healthy", balance: 1_000),
                account(broken, name: "ZZZ Broken", balance: 1_000),
            ]
        )
        // Name order would put AAA first; urgency wins.
        #expect(allocations.first?.accountID == broken)
    }

    @Test("claims are ordered largest first, ties broken by name")
    func claimOrdering() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [
                goal(name: "Zebra", saved: 100, account: id),
                goal(name: "Apple", saved: 100, account: id),
                goal(name: "Biggest", saved: 400, account: id),
            ],
            accounts: [account(id, balance: 1_000)]
        )
        let names = allocations.first?.goals.map(\.name)
        #expect(names == ["Biggest", "Apple", "Zebra"])
    }

    /// The bar is capped so it cannot run off the end; over-allocation is
    /// reported by the flag and the amount, not by a fraction above 1.
    @Test("allocated fraction is capped at 1 even when over-allocated")
    func fractionCapped() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [goal(name: "Car", saved: 5_000, account: id)],
            accounts: [account(id, balance: 1_000)]
        )
        #expect(allocations.first?.allocatedFraction == 1.0)
        #expect(allocations.first?.isOverAllocated == true)
    }

    /// A zero-balance account with claims against it is fully over-allocated
    /// rather than dividing by zero.
    @Test("a zero-balance account does not divide by zero")
    func zeroBalance() {
        let id = UUID()
        let allocations = engine.allocations(
            goals: [goal(name: "Car", saved: 100, account: id)],
            accounts: [account(id, balance: 0)]
        )
        #expect(allocations.first?.allocatedFraction == 1.0)
        #expect(allocations.first?.isOverAllocated == true)
        #expect(allocations.first?.overAllocationAmount == 100)
    }

    @Test("overAllocated returns only the accounts in trouble")
    func overAllocatedFilter() {
        let healthy = UUID()
        let broken = UUID()
        let result = engine.overAllocated(
            goals: [
                goal(name: "Fine", saved: 100, account: healthy),
                goal(name: "Too much", saved: 5_000, account: broken),
            ],
            accounts: [
                account(healthy, name: "Healthy", balance: 1_000),
                account(broken, name: "Broken", balance: 1_000),
            ]
        )
        #expect(result.count == 1)
        #expect(result.first?.accountID == broken)
    }
}
