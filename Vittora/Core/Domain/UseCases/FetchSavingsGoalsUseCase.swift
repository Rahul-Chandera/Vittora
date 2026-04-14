import Foundation

struct FetchSavingsGoalsUseCase: Sendable {
    let savingsGoalRepository: any SavingsGoalRepository

    func execute() async throws -> [SavingsGoalEntity] {
        try await savingsGoalRepository.fetchAll()
    }

    func executeActive() async throws -> [SavingsGoalEntity] {
        try await savingsGoalRepository.fetchActive()
    }

    func executeProgressSummary() async throws -> GoalProgressSummary {
        let goals = try await savingsGoalRepository.fetchAll()
        let active = goals.filter { $0.status == .active }
        let achieved = goals.filter { $0.status == .achieved }
        let totalTarget = goals.reduce(Decimal(0)) { $0 + $1.targetAmount }
        let totalSaved = goals.reduce(Decimal(0)) { $0 + $1.currentAmount }
        return GoalProgressSummary(
            totalGoals: goals.count,
            activeGoals: active.count,
            achievedGoals: achieved.count,
            totalTargetAmount: totalTarget,
            totalSavedAmount: totalSaved
        )
    }
}
