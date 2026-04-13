import Foundation

struct FetchSplitGroupsUseCase: Sendable {
    let splitGroupRepository: any SplitGroupRepository
    let payeeRepository: any PayeeRepository

    /// Returns all groups with member names resolved and outstanding balance counts.
    func execute() async throws -> [SplitGroupSummary] {
        let groups = try await splitGroupRepository.fetchAllGroups()
        let allPayees = try await payeeRepository.fetchAll()
        let payeeMap = Dictionary(uniqueKeysWithValues: allPayees.map { ($0.id, $0.name) })

        return try await withThrowingTaskGroup(of: SplitGroupSummary.self) { taskGroup in
            for group in groups {
                taskGroup.addTask {
                    let expenses = try await splitGroupRepository.fetchExpenses(forGroup: group.id)
                    let memberNames = group.memberIDs.reduce(into: [UUID: String]()) { dict, id in
                        dict[id] = payeeMap[id] ?? String(localized: "Unknown")
                    }
                    let balances = SimplifyDebtsUseCase.simplify(
                        expenses: expenses.filter { !$0.isSettled },
                        memberIDs: group.memberIDs
                    )
                    return SplitGroupSummary(
                        group: group,
                        memberNames: memberNames,
                        expenses: expenses,
                        simplifiedBalances: balances
                    )
                }
            }

            var results: [SplitGroupSummary] = []
            for try await summary in taskGroup {
                results.append(summary)
            }
            return results.sorted { $0.group.createdAt > $1.group.createdAt }
        }
    }
}
