import Foundation

@Observable
@MainActor
final class SavingsGoalListViewModel {
    private let fetchUseCase: FetchSavingsGoalsUseCase
    private let saveUseCase: SaveSavingsGoalUseCase

    var goals: [SavingsGoalEntity] = []
    var summary: GoalProgressSummary?
    var isLoading = false
    var error: String?

    var activeGoals: [SavingsGoalEntity] { goals.filter { $0.status == .active } }
    var achievedGoals: [SavingsGoalEntity] { goals.filter { $0.status == .achieved } }
    var overdueGoals: [SavingsGoalEntity] { goals.filter { $0.isOverdue } }

    init(fetchUseCase: FetchSavingsGoalsUseCase, saveUseCase: SaveSavingsGoalUseCase) {
        self.fetchUseCase = fetchUseCase
        self.saveUseCase = saveUseCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedGoals = fetchUseCase.execute()
            async let fetchedSummary = fetchUseCase.executeProgressSummary()
            (goals, summary) = try await (fetchedGoals, fetchedSummary)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func delete(id: UUID) async {
        do {
            try await saveUseCase.savingsGoalRepository.delete(id)
            goals.removeAll { $0.id == id }
            summary = recomputeSummary()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func recomputeSummary() -> GoalProgressSummary {
        GoalProgressSummary(
            totalGoals: goals.count,
            activeGoals: goals.filter { $0.status == .active }.count,
            achievedGoals: goals.filter { $0.status == .achieved }.count,
            totalTargetAmount: goals.reduce(0) { $0 + $1.targetAmount },
            totalSavedAmount: goals.reduce(0) { $0 + $1.currentAmount }
        )
    }
}
