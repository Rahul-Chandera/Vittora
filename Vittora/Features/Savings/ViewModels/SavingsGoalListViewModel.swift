import Foundation
import VittoraCore

@Observable
@MainActor
final class SavingsGoalListViewModel {
    private let fetchUseCase: FetchSavingsGoalsUseCase
    private let saveUseCase: SaveSavingsGoalUseCase
    private let accountRepository: any AccountRepository
    private let allocationEngine = SinkingFundAllocationEngine()

    var goals: [SavingsGoalEntity] = []
    var summary: GoalProgressSummary?
    var isLoading = false
    var error: String?

    /// Sinking funds (M2.5.5): what each account's goals claim against what it
    /// actually holds. Empty when no goal is linked to an account, which is the
    /// common case for a single-goal user.
    var allocations: [SinkingFundAllocationEngine.AccountAllocation] = []

    var overAllocatedAccounts: [SinkingFundAllocationEngine.AccountAllocation] {
        allocations.filter(\.isOverAllocated)
    }

    var activeGoals: [SavingsGoalEntity] { goals.filter { $0.status == .active } }
    var achievedGoals: [SavingsGoalEntity] { goals.filter { $0.status == .achieved } }
    var overdueGoals: [SavingsGoalEntity] { goals.filter { $0.isOverdue } }

    init(
        fetchUseCase: FetchSavingsGoalsUseCase,
        saveUseCase: SaveSavingsGoalUseCase,
        accountRepository: any AccountRepository
    ) {
        self.fetchUseCase = fetchUseCase
        self.saveUseCase = saveUseCase
        self.accountRepository = accountRepository
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedGoals = fetchUseCase.execute()
            async let fetchedSummary = fetchUseCase.executeProgressSummary()
            (goals, summary) = try await (fetchedGoals, fetchedSummary)
            // Allocations are secondary to the goal list, so a failure here must
            // not take the whole screen down with it — the goals still render.
            allocations = (try? await accountRepository.fetchAll())
                .map { allocationEngine.allocations(goals: goals, accounts: $0) } ?? []
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
