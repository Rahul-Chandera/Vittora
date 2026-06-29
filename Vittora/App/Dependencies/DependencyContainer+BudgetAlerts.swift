import Foundation
import VittoraCore

extension DependencyContainer {
    /// Re-evaluates budget spending thresholds and schedules any newly crossed alerts.
    @MainActor
    func refreshBudgetThresholdAlerts() async {
        try? await evaluateBudgetThresholdAlertsUseCase.execute()
    }
}
