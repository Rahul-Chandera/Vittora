import Foundation
import Testing
@testable import Vittora

@Suite("Split Group Use Case Tests")
struct SplitGroupUseCaseTests {

    // MARK: - CreateSplitGroupUseCase

    @Suite("CreateSplitGroupUseCase")
    @MainActor
    struct CreateSplitGroupUseCaseTests {

        @Test("creates group with valid name and members")
        func createsGroup() async throws {
            let repo = MockSplitGroupRepository()
            let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)
            let m1 = UUID(), m2 = UUID(), m3 = UUID()

            let group = try await useCase.execute(name: "Trip Crew", memberIDs: [m1, m2, m3])

            #expect(group.name == "Trip Crew")
            #expect(group.memberIDs == [m1, m2, m3])
            #expect(repo.groups.count == 1)
        }

        @Test("trims whitespace from name")
        func trimsName() async throws {
            let repo = MockSplitGroupRepository()
            let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)

            let group = try await useCase.execute(name: "  Roomies  ", memberIDs: [UUID(), UUID()])

            #expect(group.name == "Roomies")
        }

        @Test("throws nameTooShort for single-char name")
        func throwsNameTooShort() async {
            let repo = MockSplitGroupRepository()
            let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)

            await #expect(throws: CreateSplitGroupUseCase.GroupError.self) {
                try await useCase.execute(name: "X", memberIDs: [UUID(), UUID()])
            }
        }

        @Test("throws notEnoughMembers for single member")
        func throwsNotEnoughMembers() async {
            let repo = MockSplitGroupRepository()
            let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)

            await #expect(throws: CreateSplitGroupUseCase.GroupError.self) {
                try await useCase.execute(name: "Solo", memberIDs: [UUID()])
            }
        }

        @Test("executeUpdate updates name and members")
        func executeUpdateUpdatesGroup() async throws {
            let repo = MockSplitGroupRepository()
            let original = SplitGroup(name: "Old Name", memberIDs: [UUID(), UUID()])
            repo.seedGroup(original)

            let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)
            let newMembers = [UUID(), UUID(), UUID()]
            let updated = try await useCase.executeUpdate(
                group: original,
                name: "New Name",
                memberIDs: newMembers
            )

            #expect(updated.name == "New Name")
            #expect(updated.memberIDs == newMembers)
            let stored = repo.groups.first { $0.id == original.id }
            #expect(stored?.name == "New Name")
        }
    }

    // MARK: - SimplifyDebtsUseCase

    @Suite("SimplifyDebtsUseCase")
    struct SimplifyDebtsUseCaseTests {

        @Test("returns empty balances when no expenses")
        func emptyExpensesGivesEmptyBalances() {
            let m1 = UUID(), m2 = UUID()
            let result = SimplifyDebtsUseCase.simplify(expenses: [], memberIDs: [m1, m2])
            #expect(result.isEmpty)
        }

        @Test("two members: one expense produces single transfer")
        func twoMembersSingleExpense() {
            let payer = UUID()
            let other = UUID()
            let expense = GroupExpense(
                groupID: UUID(),
                paidByMemberID: payer,
                amount: 100,
                title: "Dinner",
                shares: [
                    SplitShare(memberID: payer, amount: 50),
                    SplitShare(memberID: other, amount: 50)
                ]
            )

            let result = SimplifyDebtsUseCase.simplify(
                expenses: [expense],
                memberIDs: [payer, other]
            )

            #expect(result.count == 1)
            #expect(result.first?.fromMemberID == other)
            #expect(result.first?.toMemberID == payer)
            #expect(result.first?.amount == 50)
        }

        @Test("three members: minimizes transfers")
        func threeMembersMinimizesTransfers() {
            let a = UUID(), b = UUID(), c = UUID()
            // A pays $90: B owes $30, C owes $30, A owes $30 (equal split)
            // Net: A is owed $60, B owes $30, C owes $30
            let expense = GroupExpense(
                groupID: UUID(),
                paidByMemberID: a,
                amount: 90,
                title: "Hotel",
                shares: [
                    SplitShare(memberID: a, amount: 30),
                    SplitShare(memberID: b, amount: 30),
                    SplitShare(memberID: c, amount: 30)
                ]
            )

            let result = SimplifyDebtsUseCase.simplify(
                expenses: [expense],
                memberIDs: [a, b, c]
            )

            #expect(result.count == 2)
            let total = result.reduce(Decimal(0)) { $0 + $1.amount }
            #expect(total == 60)
        }

        @Test("settled expenses are excluded")
        func settledExpensesExcluded() {
            let payer = UUID(), other = UUID()
            let settled = GroupExpense(
                groupID: UUID(),
                paidByMemberID: payer,
                amount: 100,
                title: "Old dinner",
                shares: [
                    SplitShare(memberID: payer, amount: 50),
                    SplitShare(memberID: other, amount: 50)
                ],
                isSettled: true
            )

            let result = SimplifyDebtsUseCase.simplify(
                expenses: [settled],
                memberIDs: [payer, other]
            )

            #expect(result.isEmpty)
        }
    }
}
