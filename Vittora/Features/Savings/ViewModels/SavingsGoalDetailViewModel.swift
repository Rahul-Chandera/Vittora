import Foundation

@Observable
@MainActor
final class SavingsGoalDetailViewModel {
    private let saveUseCase: SaveSavingsGoalUseCase

    var goal: SavingsGoalEntity
    var isLoading = false
    var error: String?

    // Contribution form state
    var contributionString = ""
    var isAddingContribution = false

    var contributionAmount: Decimal {
        Decimal(string: contributionString.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    var canContribute: Bool { contributionAmount > 0 && goal.status == .active }

    init(goal: SavingsGoalEntity, saveUseCase: SaveSavingsGoalUseCase) {
        self.goal = goal
        self.saveUseCase = saveUseCase
    }

    func addContribution() async {
        guard canContribute else { return }
        isAddingContribution = true
        error = nil
        do {
            goal = try await saveUseCase.executeAddContribution(
                goalID: goal.id,
                amount: contributionAmount
            )
            contributionString = ""
        } catch {
            self.error = error.localizedDescription
        }
        isAddingContribution = false
    }

    func togglePause() async {
        var updated = goal
        updated.status = goal.status == .paused ? .active : .paused
        do {
            try await saveUseCase.executeUpdate(updated)
            goal = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAchieved() async {
        var updated = goal
        updated.status = .achieved
        updated.currentAmount = goal.targetAmount
        do {
            try await saveUseCase.executeUpdate(updated)
            goal = updated
        } catch {
            self.error = error.localizedDescription
        }
    }
}
