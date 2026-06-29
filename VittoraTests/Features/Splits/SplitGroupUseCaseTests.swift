import Foundation
import Testing
import VittoraCore
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

            let result = SimplifyDebtsUseCase().execute(
                groupID: UUID(),
                expenses: [settled],
                memberIDs: [payer, other]
            )

            #expect(result.isEmpty)
        }

        @Test("rounded transfers net all member balances to zero")
        func transfersNetToZero() {
            let a = UUID(), b = UUID(), c = UUID(), d = UUID()
            let members = [a, b, c, d]

            let amounts: [Decimal] = [Decimal(string: "0.07")!, 10, 33.33, 100]
            var expenses: [GroupExpense] = []
            for amount in amounts {
                let ideal = members.map { _ in amount / Decimal(members.count) }
                let shares = SplitRounding.allocate(amount: amount, memberIDs: members, idealParts: ideal)
                expenses.append(GroupExpense(
                    groupID: UUID(),
                    paidByMemberID: a,
                    amount: amount,
                    title: "Test",
                    shares: shares
                ))
            }

            var initialNet = members.reduce(into: [UUID: Decimal]()) { $0[$1] = 0 }
            for expense in expenses {
                let payer = expense.paidByMemberID
                for share in expense.shares where share.memberID != payer {
                    initialNet[share.memberID, default: 0] -= share.amount
                    initialNet[payer, default: 0] += share.amount
                }
            }
            for id in members {
                initialNet[id] = initialNet[id]?.rounded(scale: SplitRounding.moneyScale) ?? 0
            }

            let transfers = SimplifyDebtsUseCase.simplify(expenses: expenses, memberIDs: members)
            let after = SimplifyDebtsUseCase.netAfterTransfers(initialNet: initialNet, transfers: transfers)

            for id in members {
                #expect(abs(after[id, default: 0]) <= SplitRounding.moneyEpsilon)
            }
        }
    }

    // MARK: - AddGroupExpenseUseCase share calculation (A12)

    @Suite("AddGroupExpenseUseCase share calculation")
    @MainActor
    struct AddGroupExpenseShareCalculationTests {
        private let useCase = AddGroupExpenseUseCase(splitGroupRepository: MockSplitGroupRepository())

        @Test("equal splits sum exactly across member counts and amounts")
        func equalSplitsSumExactly() throws {
            let amounts: [Decimal] = [Decimal(string: "0.07")!, 1, 10, 33.33, 100]
            for amount in amounts {
                for count in 2...8 {
                    let ids = (0..<count).map { _ in UUID() }
                    let shares = try useCase.calculateShares(
                        amount: amount, method: .equal, memberIDs: ids, customValues: [:]
                    )
                    #expect(SplitRounding.sharesBalance(amount, shares))
                    #expect(SplitRounding.allSharesNonNegative(shares))
                }
            }
        }

        @Test("percentage splits sum exactly and validate total is 100")
        func percentageSplitsSumExactly() throws {
            let a = UUID(), b = UUID(), c = UUID()
            let ids = [a, b, c]
            let shares = try useCase.calculateShares(
                amount: 10,
                method: .percentage,
                memberIDs: ids,
                customValues: [a: 50, b: 30, c: 20]
            )
            #expect(SplitRounding.sharesBalance(10, shares))
            #expect(SplitRounding.allSharesNonNegative(shares))
        }

        @Test("percentage inputs must sum to 100 within tolerance")
        func percentageSumValidation() {
            let ids = [UUID(), UUID(), UUID()]
            #expect(throws: AddGroupExpenseUseCase.ExpenseError.self) {
                try useCase.calculateShares(
                    amount: 10,
                    method: .percentage,
                    memberIDs: ids,
                    customValues: [ids[0]: 33, ids[1]: 33, ids[2]: 33]
                )
            }
        }

        @Test("shares method absorbs remainder without negative last share")
        func sharesSplitAvoidsNegativeLastShare() throws {
            let ids = [UUID(), UUID()]
            let shares = try useCase.calculateShares(
                amount: Decimal(string: "0.07")!,
                method: .shares,
                memberIDs: ids,
                customValues: [ids[0]: 1, ids[1]: 1]
            )
            #expect(SplitRounding.sharesBalance(Decimal(string: "0.07")!, shares))
            #expect(SplitRounding.allSharesNonNegative(shares))
        }

        @Test("shares method rejects zero total weight")
        func sharesRejectsZeroWeights() {
            let ids = [UUID(), UUID()]
            #expect(throws: AddGroupExpenseUseCase.ExpenseError.self) {
                try useCase.calculateShares(
                    amount: 10,
                    method: .shares,
                    memberIDs: ids,
                    customValues: [ids[0]: 0, ids[1]: 0]
                )
            }
        }
    }
}
