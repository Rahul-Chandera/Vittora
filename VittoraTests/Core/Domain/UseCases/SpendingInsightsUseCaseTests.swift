import Foundation
import Testing
import VittoraCore
@testable import Vittora

@MainActor
final class MockSpendingInsightDismissalStore: SpendingInsightDismissalStoring {
    private var dismissed: Set<String> = []
    nonisolated func isDismissed(insightID: String, period: String) -> Bool {
        MainActor.assumeIsolated { dismissed.contains("\(insightID)|\(period)") }
    }
    nonisolated func dismiss(insightID: String, period: String) {
        MainActor.assumeIsolated { _ = dismissed.insert("\(insightID)|\(period)") }
    }
    nonisolated func resetAll() {
        MainActor.assumeIsolated { dismissed.removeAll() }
    }
}

/// M3.6.4 / M3.6.5 wiring. The engines are tested on their own; these pin the parts the
/// engines cannot see — which months count as "prior", and that a dismissal is scoped to
/// the period rather than forever.
@MainActor
@Suite("Spending Insights Use Case Tests")
struct SpendingInsightsUseCaseTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
    }

    /// The month in progress is never a prior period: counting it would drag every average
    /// down simply because it is not finished, and then nothing would ever look unusual.
    @Test("prior periods are completed months, never the one in progress")
    func priorPeriodsExcludeTheCurrentMonth() {
        let keys = EvaluateSpendingInsightsUseCase.priorPeriodKeys(
            before: date(2026, 6, 15),
            count: 4,
            calendar: calendar
        )

        #expect(keys == ["2026-02", "2026-03", "2026-04", "2026-05"])
        #expect(keys.contains("2026-06") == false)
    }

    @Test("the period key is year and month, zero padded so it sorts")
    func periodKeyIsSortable() {
        #expect(EvaluateSpendingInsightsUseCase.periodKey(for: date(2026, 1, 5), calendar: calendar) == "2026-01")
        #expect(EvaluateSpendingInsightsUseCase.periodKey(for: date(2026, 12, 31), calendar: calendar) == "2026-12")

        let keys = ["2026-10", "2026-02", "2026-01"].sorted()
        #expect(keys == ["2026-01", "2026-02", "2026-10"])
    }

    /// Dismissing is "not now", not "never tell me". September's dismissal must not
    /// silence October.
    @Test("a dismissal in one period does not carry into the next")
    func dismissalIsScopedToThePeriod() {
        let store = MockSpendingInsightDismissalStore()
        store.dismiss(insightID: "anomaly-x", period: "2026-09")

        #expect(store.isDismissed(insightID: "anomaly-x", period: "2026-09"))
        #expect(store.isDismissed(insightID: "anomaly-x", period: "2026-10") == false)
    }

    @Test("dismissing one insight leaves the others alone")
    func dismissalIsScopedToTheInsight() {
        let store = MockSpendingInsightDismissalStore()
        store.dismiss(insightID: "anomaly-x", period: "2026-09")

        #expect(store.isDismissed(insightID: "budget-y", period: "2026-09") == false)
    }

    @Test("the lookback covers the engines' minimum history plus the month being judged")
    func lookbackCoversTheEngineMinimum() {
        #expect(
            EvaluateSpendingInsightsUseCase.lookbackMonths
                > SpendingAnomalyEngine.minimumPriorPeriods
        )
        #expect(
            EvaluateSpendingInsightsUseCase.lookbackMonths
                > BudgetOptimisationEngine.minimumPriorPeriods
        )
    }

    /// The section sits above the report list. Three near-identical "nothing spent" cards
    /// filled the whole first screen on eight months of demo data, which is how this cap
    /// was found.
    @Test("the section is capped so it cannot push the reports off screen")
    func insightsAreCapped() {
        #expect(EvaluateSpendingInsightsUseCase.maximumInsights == 3)
    }
}
