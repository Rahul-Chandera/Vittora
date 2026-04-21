import Foundation
import Observation

@Observable
@MainActor
final class SubscriptionSummaryViewModel {
    var activeRules: [RecurringRuleEntity] = []
    var costSummary: SubscriptionCostSummary?
    var isLoading = false

    private let fetchUseCase: FetchRecurringRulesUseCase
    private let calculateCostUseCase: CalculateSubscriptionCostUseCase

    init(
        fetchUseCase: FetchRecurringRulesUseCase,
        calculateCostUseCase: CalculateSubscriptionCostUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.calculateCostUseCase = calculateCostUseCase
    }

    func load() async {
        isLoading = true

        do {
            let rules = try await fetchUseCase.executeActive()
            self.activeRules = rules
            self.costSummary = calculateCostUseCase.execute(rules: rules)
        } catch {
            // Silent fail for summary, optionally log
        }

        isLoading = false
    }

    func monthlyCost(for rule: RecurringRuleEntity) -> Decimal {
        calculateCostUseCase.monthlyEquivalent(
            amount: rule.templateAmount,
            frequency: rule.frequency
        )
    }
}
