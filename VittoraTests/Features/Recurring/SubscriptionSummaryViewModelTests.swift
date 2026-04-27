import Foundation
import Testing
@testable import Vittora

@Suite("SubscriptionSummaryViewModel Tests")
@MainActor
struct SubscriptionSummaryViewModelTests {

    private func makeViewModel(recurringRepo: MockRecurringRuleRepository = MockRecurringRuleRepository()) -> SubscriptionSummaryViewModel {
        SubscriptionSummaryViewModel(
            fetchUseCase: FetchRecurringRulesUseCase(repository: recurringRepo),
            calculateCostUseCase: CalculateSubscriptionCostUseCase()
        )
    }

    // MARK: - Initial state

    @Test("starts with empty activeRules and nil costSummary")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.activeRules.isEmpty)
        #expect(vm.costSummary == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - load()

    @Test("load() clears isLoading after completion")
    func loadClearsIsLoading() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.isLoading == false)
    }

    @Test("load() with no rules sets empty activeRules and zero cost")
    func loadNoRules() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.activeRules.isEmpty)
        #expect(vm.costSummary?.ruleCount == 0)
    }

    @Test("load() populates activeRules from repository")
    func loadPopulatesRules() async {
        let repo = MockRecurringRuleRepository()
        let rule1 = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: Date(),
            templateAmount: 9.99
        )
        let rule2 = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: Date(),
            templateAmount: 14.99
        )
        await repo.seed(rule1)
        await repo.seed(rule2)

        let vm = makeViewModel(recurringRepo: repo)
        await vm.load()

        #expect(vm.activeRules.count == 2)
    }

    @Test("load() computes correct monthly cost from active rules")
    func loadComputesMonthlyCost() async {
        let repo = MockRecurringRuleRepository()
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: Date(),
            templateAmount: 9.99
        )
        await repo.seed(rule)

        let vm = makeViewModel(recurringRepo: repo)
        await vm.load()

        #expect(vm.costSummary != nil)
        #expect(vm.costSummary?.ruleCount == 1)
        #expect(vm.costSummary?.monthlyCost ?? 0 > 0)
    }

    @Test("load() silently ignores repository failure (no error state)")
    func loadSilentlyIgnoresError() async {
        let repo = MockRecurringRuleRepository()
        await repo.setShouldThrow(true)

        let vm = makeViewModel(recurringRepo: repo)
        await vm.load()

        #expect(vm.isLoading == false)
    }
}

extension MockRecurringRuleRepository {
    func setShouldThrow(_ value: Bool) {
        shouldThrowError = value
    }
}
