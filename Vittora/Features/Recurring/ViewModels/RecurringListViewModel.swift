import Foundation
import Observation

@Observable
@MainActor
final class RecurringListViewModel {
    var rules: [RecurringRuleEntity] = []
    var costSummary: SubscriptionCostSummary?
    var isLoading = false
    var error: String?

    private let fetchUseCase: FetchRecurringRulesUseCase
    private let deleteUseCase: DeleteRecurringRuleUseCase
    private let pauseResumeUseCase: PauseResumeRuleUseCase
    private let calculateCostUseCase: CalculateSubscriptionCostUseCase

    init(
        fetchUseCase: FetchRecurringRulesUseCase,
        deleteUseCase: DeleteRecurringRuleUseCase,
        pauseResumeUseCase: PauseResumeRuleUseCase,
        calculateCostUseCase: CalculateSubscriptionCostUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
        self.pauseResumeUseCase = pauseResumeUseCase
        self.calculateCostUseCase = calculateCostUseCase
    }

    /// Group rules by frequency label for display
    var grouped: [(label: String, rules: [RecurringRuleEntity])] {
        let groupedDict = Dictionary(grouping: rules) { rule in
            frequencyLabel(rule.frequency)
        }

        let frequencyOrder: [String] = ["Daily", "Weekly", "Bi-weekly", "Monthly", "Quarterly", "Yearly", "Custom"]
        return frequencyOrder.compactMap { label in
            if let groupedRules = groupedDict[label] {
                return (label: label, rules: groupedRules.sorted { $0.nextDate < $1.nextDate })
            }
            return nil
        }
    }

    func loadRules() async {
        isLoading = true
        error = nil

        do {
            let fetchedRules = try await fetchUseCase.execute()
            self.rules = fetchedRules
            self.costSummary = calculateCostUseCase.execute(rules: fetchedRules)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteRule(id: UUID) async {
        error = nil

        do {
            try await deleteUseCase.execute(id: id)
            await loadRules()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePause(id: UUID) async {
        error = nil

        do {
            try await pauseResumeUseCase.execute(id: id)
            await loadRules()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Get localized label for frequency
    private func frequencyLabel(_ frequency: RecurrenceFrequency) -> String {
        switch frequency {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        case .custom(let days):
            return "Custom"
        }
    }
}
