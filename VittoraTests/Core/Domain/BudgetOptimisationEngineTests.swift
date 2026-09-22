import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M3.6.5. Observations, never instructions — and like the anomaly engine, most of what
/// matters is what it declines to say.
@Suite("Budget Optimisation Engine Tests")
struct BudgetOptimisationEngineTests {

    private func series(
        name: String = "Dining",
        limit: Decimal,
        prior: [Decimal]
    ) -> BudgetOptimisationEngine.BudgetSeries {
        BudgetOptimisationEngine.BudgetSeries(
            budgetID: UUID(),
            categoryName: name,
            limit: limit,
            priorSpend: prior
        )
    }

    @Test("a budget under-spent every period is reported with the typical spend")
    func consistentUnderSpendIsReported() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 10_000, prior: [4_000, 3_500, 4_200])
        ])

        #expect(observations.count == 1)
        let observation = try! #require(observations.first)
        #expect(observation.kind == .consistentlyUnderSpent)
        #expect(observation.typicalSpend == 4_000)
        #expect(observation.difference == 6_000)
        #expect(observation.periodCount == 3)
    }

    @Test("a budget exceeded every period is reported as over-spent")
    func consistentOverSpendIsReported() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 5_000, prior: [6_000, 5_500, 7_000])
        ])

        #expect(observations.first?.kind == .consistentlyOverSpent)
        // Negative headroom is what makes an over-spend concrete.
        #expect(observations.first?.difference == -1_000)
    }

    @Test("a budget with no spend at all is reported as unused")
    func unusedBudgetIsReported() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 3_000, prior: [0, 0, 0])
        ])
        #expect(observations.first?.kind == .unused)
    }

    /// One quiet month inside an otherwise tight budget is not a pattern, and reporting it
    /// as one is how this surface starts being ignored.
    @Test("a single quiet period does not make a budget under-spent")
    func oneQuietPeriodIsNotAPattern() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 10_000, prior: [9_500, 2_000, 9_800])
        ])
        #expect(observations.isEmpty)
    }

    /// Judging a budget on a month that is half over would call every budget under-spent,
    /// which is why the series excludes the period in progress — asserted here by showing
    /// that a mixed history says nothing.
    @Test("a budget that is sometimes over and sometimes under says nothing")
    func mixedHistoryIsSilent() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 5_000, prior: [5_500, 4_000, 5_200])
        ])
        #expect(observations.isEmpty)
    }

    @Test("too little history means no observation")
    func shortHistoryIsSilent() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 10_000, prior: [1_000, 1_200])
        ])
        #expect(observations.isEmpty)
    }

    /// Shaving a trivial amount off a budget is not worth a card.
    @Test("headroom too small to act on is ignored")
    func trivialHeadroomIsIgnored() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 1_000, prior: [560, 550, 540])
        ])
        #expect(observations.isEmpty)
    }

    @Test("a budget with no limit is skipped rather than divided by")
    func zeroLimitIsSkipped() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(limit: 0, prior: [100, 200, 300])
        ])
        #expect(observations.isEmpty)
    }

    /// A budget breached every month is the one worth acting on, so it leads.
    @Test("over-spends lead, then unused, then under-spends")
    func resultsAreRankedByUrgency() {
        let observations = BudgetOptimisationEngine.evaluate([
            series(name: "Under", limit: 10_000, prior: [2_000, 2_000, 2_000]),
            series(name: "Unused", limit: 3_000, prior: [0, 0, 0]),
            series(name: "Over", limit: 5_000, prior: [6_000, 6_000, 6_000]),
        ])

        #expect(observations.map(\.categoryName) == ["Over", "Unused", "Under"])
    }

    @Test("an empty input produces nothing rather than crashing")
    func emptyInputIsEmpty() {
        #expect(BudgetOptimisationEngine.evaluate([]).isEmpty)
    }
}
