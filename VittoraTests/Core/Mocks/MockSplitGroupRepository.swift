import Foundation
@testable import Vittora

@MainActor
final class MockSplitGroupRepository: SplitGroupRepository {
    private(set) var groups: [SplitGroup] = []
    private(set) var expenses: [GroupExpense] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    // MARK: - Group CRUD

    func fetchAllGroups() async throws -> [SplitGroup] {
        if shouldThrowError { throw throwError }
        return groups
    }

    func fetchGroupByID(_ id: UUID) async throws -> SplitGroup? {
        if shouldThrowError { throw throwError }
        return groups.first { $0.id == id }
    }

    func createGroup(_ group: SplitGroup) async throws {
        if shouldThrowError { throw throwError }
        groups.append(group)
    }

    func updateGroup(_ group: SplitGroup) async throws {
        if shouldThrowError { throw throwError }
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else {
            throw VittoraError.notFound(String(localized: "Split group not found"))
        }
        groups[index] = group
    }

    func deleteGroup(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            throw VittoraError.notFound(String(localized: "Split group not found"))
        }
        groups.remove(at: index)
    }

    // MARK: - Expense CRUD

    func fetchExpenses(forGroup groupID: UUID) async throws -> [GroupExpense] {
        if shouldThrowError { throw throwError }
        return expenses.filter { $0.groupID == groupID }
    }

    func fetchExpenseByID(_ id: UUID) async throws -> GroupExpense? {
        if shouldThrowError { throw throwError }
        return expenses.first { $0.id == id }
    }

    func createExpense(_ expense: GroupExpense) async throws {
        if shouldThrowError { throw throwError }
        expenses.append(expense)
    }

    func updateExpense(_ expense: GroupExpense) async throws {
        if shouldThrowError { throw throwError }
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else {
            throw VittoraError.notFound(String(localized: "Group expense not found"))
        }
        expenses[index] = expense
    }

    func deleteExpense(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        guard let index = expenses.firstIndex(where: { $0.id == id }) else {
            throw VittoraError.notFound(String(localized: "Group expense not found"))
        }
        expenses.remove(at: index)
    }

    // MARK: - Test helpers

    func seedGroup(_ group: SplitGroup) { groups.append(group) }
    func seedExpense(_ expense: GroupExpense) { expenses.append(expense) }
}
