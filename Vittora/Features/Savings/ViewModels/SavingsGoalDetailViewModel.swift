import Foundation
import VittoraCore

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

    private var parsedContribution: Decimal? {
        Decimal(localizedAmount: contributionString)
    }

    var canContribute: Bool {
        guard let parsedContribution, parsedContribution > 0 else { return false }
        return goal.status == .active
    }

    init(goal: SavingsGoalEntity, saveUseCase: SaveSavingsGoalUseCase) {
        self.goal = goal
        self.saveUseCase = saveUseCase
    }

    func addContribution() async {
        guard let parsedContribution, parsedContribution > 0, goal.status == .active else { return }
        isAddingContribution = true
        error = nil
        do {
            goal = try await saveUseCase.executeAddContribution(
                goalID: goal.id,
                amount: parsedContribution
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
