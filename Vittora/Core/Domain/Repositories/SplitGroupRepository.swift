import Foundation

protocol SplitGroupRepository: Sendable {
    // MARK: - Group CRUD
    func fetchAllGroups() async throws -> [SplitGroup]
    func fetchGroupByID(_ id: UUID) async throws -> SplitGroup?
    func createGroup(_ group: SplitGroup) async throws
    func updateGroup(_ group: SplitGroup) async throws
    func deleteGroup(_ id: UUID) async throws

    // MARK: - Expense CRUD
    func fetchExpenses(forGroup groupID: UUID) async throws -> [GroupExpense]
    func fetchExpenseByID(_ id: UUID) async throws -> GroupExpense?
    func createExpense(_ expense: GroupExpense) async throws
    func updateExpense(_ expense: GroupExpense) async throws
    func deleteExpense(_ id: UUID) async throws
}
