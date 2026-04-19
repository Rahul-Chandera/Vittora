import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataSplitGroupRepository Tests")
struct SwiftDataSplitGroupRepositoryTests {

    private func makeRepo() throws -> SwiftDataSplitGroupRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataSplitGroupRepository(modelContainer: container)
    }

    // MARK: - Group CRUD

    @Test("createGroup and fetchAllGroups returns inserted group")
    func testCreateGroupAndFetchAll() async throws {
        let repo = try makeRepo()
        let memberID1 = UUID()
        let memberID2 = UUID()
        let group = SplitGroup(
            id: UUID(),
            name: "Road Trip",
            memberIDs: [memberID1, memberID2],
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.createGroup(group)
        let all = try await repo.fetchAllGroups()

        #expect(all.count == 1)
        #expect(all.first?.id == group.id)
        #expect(all.first?.name == "Road Trip")
        #expect(all.first?.memberIDs.count == 2)
    }

    @Test("fetchGroupByID returns correct group")
    func testFetchGroupByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let group = SplitGroup(
            id: id,
            name: "Camping Trip",
            memberIDs: [UUID()],
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.createGroup(group)

        let found = try await repo.fetchGroupByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.name == "Camping Trip")
    }

    @Test("fetchGroupByID returns nil for unknown ID")
    func testFetchGroupByIDReturnsNil() async throws {
        let repo = try makeRepo()

        let result = try await repo.fetchGroupByID(UUID())

        #expect(result == nil)
    }

    @Test("updateGroup modifies persisted fields")
    func testUpdateGroup() async throws {
        let repo = try makeRepo()
        let id = UUID()
        var group = SplitGroup(
            id: id,
            name: "Old Group Name",
            memberIDs: [UUID()],
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.createGroup(group)

        let newMember = UUID()
        group.name = "New Group Name"
        group.memberIDs.append(newMember)
        group.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.updateGroup(group)

        let updated = try await repo.fetchGroupByID(id)
        #expect(updated?.name == "New Group Name")
        #expect(updated?.memberIDs.count == 2)
    }

    @Test("updateGroup throws notFound for missing group ID")
    func testUpdateGroupNotFound() async throws {
        let repo = try makeRepo()
        let group = SplitGroup(
            id: UUID(), name: "Ghost Group",
            createdAt: Date(timeIntervalSince1970: 4_000_000),
            updatedAt: Date(timeIntervalSince1970: 4_000_000)
        )

        do {
            try await repo.updateGroup(group)
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    @Test("deleteGroup removes group and its expenses")
    func testDeleteGroup() async throws {
        let repo = try makeRepo()
        let groupID = UUID()
        let memberID = UUID()
        let group = SplitGroup(
            id: groupID, name: "Weekend Trip",
            memberIDs: [memberID],
            createdAt: Date(timeIntervalSince1970: 5_000_000),
            updatedAt: Date(timeIntervalSince1970: 5_000_000)
        )
        try await repo.createGroup(group)

        // Add an expense for this group
        let expense = GroupExpense(
            id: UUID(),
            groupID: groupID,
            paidByMemberID: memberID,
            amount: 100,
            title: "Hotel",
            date: Date(timeIntervalSince1970: 5_100_000),
            createdAt: Date(timeIntervalSince1970: 5_100_000),
            updatedAt: Date(timeIntervalSince1970: 5_100_000)
        )
        try await repo.createExpense(expense)

        try await repo.deleteGroup(groupID)

        let allGroups = try await repo.fetchAllGroups()
        let expenses = try await repo.fetchExpenses(forGroup: groupID)

        #expect(allGroups.isEmpty)
        #expect(expenses.isEmpty)
    }

    @Test("deleteGroup throws notFound for missing group ID")
    func testDeleteGroupNotFound() async throws {
        let repo = try makeRepo()

        do {
            try await repo.deleteGroup(UUID())
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    // MARK: - Expense CRUD

    @Test("createExpense and fetchExpenses returns inserted expense")
    func testCreateExpenseAndFetchExpenses() async throws {
        let repo = try makeRepo()
        let groupID = UUID()
        let paidByID = UUID()
        let group = SplitGroup(
            id: groupID, name: "Test Group",
            memberIDs: [paidByID],
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        )
        try await repo.createGroup(group)

        let expense = GroupExpense(
            id: UUID(),
            groupID: groupID,
            paidByMemberID: paidByID,
            amount: 150,
            title: "Dinner",
            date: Date(timeIntervalSince1970: 6_100_000),
            splitMethod: .equal,
            shares: [SplitShare(memberID: paidByID, amount: 150)],
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        )

        try await repo.createExpense(expense)
        let expenses = try await repo.fetchExpenses(forGroup: groupID)

        #expect(expenses.count == 1)
        #expect(expenses.first?.id == expense.id)
        #expect(expenses.first?.title == "Dinner")
        #expect(expenses.first?.amount == 150)
        #expect(expenses.first?.paidByMemberID == paidByID)
    }

    @Test("fetchExpenseByID returns correct expense")
    func testFetchExpenseByID() async throws {
        let repo = try makeRepo()
        let groupID = UUID()
        let expenseID = UUID()
        let paidByID = UUID()

        let group = SplitGroup(
            id: groupID, name: "Test Group",
            memberIDs: [paidByID],
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        )
        try await repo.createGroup(group)

        let expense = GroupExpense(
            id: expenseID,
            groupID: groupID,
            paidByMemberID: paidByID,
            amount: 200,
            title: "Groceries",
            date: Date(timeIntervalSince1970: 7_100_000),
            createdAt: Date(timeIntervalSince1970: 7_100_000),
            updatedAt: Date(timeIntervalSince1970: 7_100_000)
        )
        try await repo.createExpense(expense)

        let found = try await repo.fetchExpenseByID(expenseID)

        #expect(found != nil)
        #expect(found?.id == expenseID)
        #expect(found?.title == "Groceries")
    }

    @Test("fetchExpenseByID returns nil for unknown ID")
    func testFetchExpenseByIDReturnsNil() async throws {
        let repo = try makeRepo()

        let result = try await repo.fetchExpenseByID(UUID())

        #expect(result == nil)
    }

    @Test("updateExpense modifies persisted fields")
    func testUpdateExpense() async throws {
        let repo = try makeRepo()
        let groupID = UUID()
        let expenseID = UUID()
        let paidByID = UUID()

        let group = SplitGroup(
            id: groupID, name: "Update Test Group",
            memberIDs: [paidByID],
            createdAt: Date(timeIntervalSince1970: 8_000_000),
            updatedAt: Date(timeIntervalSince1970: 8_000_000)
        )
        try await repo.createGroup(group)

        var expense = GroupExpense(
            id: expenseID,
            groupID: groupID,
            paidByMemberID: paidByID,
            amount: 50,
            title: "Old Title",
            date: Date(timeIntervalSince1970: 8_100_000),
            isSettled: false,
            createdAt: Date(timeIntervalSince1970: 8_100_000),
            updatedAt: Date(timeIntervalSince1970: 8_100_000)
        )
        try await repo.createExpense(expense)

        expense.title = "New Title"
        expense.amount = 75
        expense.isSettled = true
        expense.updatedAt = Date(timeIntervalSince1970: 8_200_000)
        try await repo.updateExpense(expense)

        let updated = try await repo.fetchExpenseByID(expenseID)
        #expect(updated?.title == "New Title")
        #expect(updated?.amount == 75)
        #expect(updated?.isSettled == true)
    }

    @Test("updateExpense throws notFound for missing expense ID")
    func testUpdateExpenseNotFound() async throws {
        let repo = try makeRepo()
        let expense = GroupExpense(
            id: UUID(),
            groupID: UUID(),
            paidByMemberID: UUID(),
            amount: 30,
            title: "Ghost Expense",
            date: Date(timeIntervalSince1970: 9_000_000),
            createdAt: Date(timeIntervalSince1970: 9_000_000),
            updatedAt: Date(timeIntervalSince1970: 9_000_000)
        )

        do {
            try await repo.updateExpense(expense)
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    @Test("deleteExpense removes the expense")
    func testDeleteExpense() async throws {
        let repo = try makeRepo()
        let groupID = UUID()
        let expenseID = UUID()
        let paidByID = UUID()

        let group = SplitGroup(
            id: groupID, name: "Delete Expense Test",
            memberIDs: [paidByID],
            createdAt: Date(timeIntervalSince1970: 10_000_000),
            updatedAt: Date(timeIntervalSince1970: 10_000_000)
        )
        try await repo.createGroup(group)

        let expense = GroupExpense(
            id: expenseID,
            groupID: groupID,
            paidByMemberID: paidByID,
            amount: 60,
            title: "To Delete",
            date: Date(timeIntervalSince1970: 10_100_000),
            createdAt: Date(timeIntervalSince1970: 10_100_000),
            updatedAt: Date(timeIntervalSince1970: 10_100_000)
        )
        try await repo.createExpense(expense)

        try await repo.deleteExpense(expenseID)
        let expenses = try await repo.fetchExpenses(forGroup: groupID)

        #expect(expenses.isEmpty)
    }

    @Test("deleteExpense throws notFound for missing expense ID")
    func testDeleteExpenseNotFound() async throws {
        let repo = try makeRepo()

        do {
            try await repo.deleteExpense(UUID())
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }
}
