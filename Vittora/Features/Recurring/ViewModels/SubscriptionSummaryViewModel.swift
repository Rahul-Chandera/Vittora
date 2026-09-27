import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class SubscriptionSummaryViewModel {
    var activeRules: [RecurringRuleEntity] = []
    var costSummary: SubscriptionCostSummary?
    var isLoading = false

    private let fetchUseCase: FetchRecurringRulesUseCase
    private let calculateCostUseCase: CalculateSubscriptionCostUseCase

    private let categoryRepository: any CategoryRepository

    init(
        fetchUseCase: FetchRecurringRulesUseCase,
        calculateCostUseCase: CalculateSubscriptionCostUseCase,
        categoryRepository: any CategoryRepository
    ) {
        self.fetchUseCase = fetchUseCase
        self.calculateCostUseCase = calculateCostUseCase
        self.categoryRepository = categoryRepository
    }

    func load() async {
        isLoading = true

        do {
            let rules = try await fetchUseCase.executeActive()
            self.activeRules = rules
            // Needed to keep income rules out of a figure headed
            // "Monthly Spending"; see CalculateSubscriptionCostUseCase.
            let categories = try await categoryRepository.fetchAll()
            self.costSummary = calculateCostUseCase.execute(
                rules: rules,
                incomeCategoryIDs: Set(categories.filter { $0.type == .income }.map(\.id))
            )
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
