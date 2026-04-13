import Foundation

struct SettleGroupExpenseUseCase: Sendable {
    let splitGroupRepository: any SplitGroupRepository

    /// Marks a single expense as settled.
    func settleExpense(_ expense: GroupExpense) async throws {
        var updated = expense
        updated.isSettled = true
        try await splitGroupRepository.updateExpense(updated)
    }

    /// Marks all unsettled expenses in a group as settled.
    func settleAll(in group: SplitGroup) async throws {
        let expenses = try await splitGroupRepository.fetchExpenses(forGroup: group.id)
        let unsettled = expenses.filter { !$0.isSettled }
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for expense in unsettled {
                taskGroup.addTask {
                    var updated = expense
                    updated.isSettled = true
                    try await splitGroupRepository.updateExpense(updated)
                }
            }
            for try await _ in taskGroup {}
        }
    }
}
