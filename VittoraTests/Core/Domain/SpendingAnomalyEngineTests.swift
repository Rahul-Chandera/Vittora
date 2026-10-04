import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M3.6.4. Every guard here exists to stop a flag the user would rightly ignore — an
/// advisory surface that cries wolf gets dismissed wholesale, taking the useful flags
/// with it. So the tests that matter are the ones asserting silence.
@Suite("Spending Anomaly Engine Tests")
struct SpendingAnomalyEngineTests {

    private func series(
        name: String = "Dining",
        prior: [Decimal],
        current: Decimal
    ) -> SpendingAnomalyEngine.CategorySeries {
        SpendingAnomalyEngine.CategorySeries(
            categoryID: UUID(),
            categoryName: name,
            priorAmounts: prior,
            currentAmount: current
        )
    }

    @Test("a category well above its own norm is flagged")
    func spikeIsFlagged() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [2_000, 2_100, 1_900], current: 6_000)
        ])

        #expect(anomalies.count == 1)
        let anomaly = try! #require(anomalies.first)
        #expect(anomaly.typicalAmount == 2_000)
        #expect(anomaly.difference == 4_000)
        #expect(anomaly.multiple == 3)
        #expect(anomaly.priorPeriodCount == 3)
    }

    /// Two months is not a pattern. Calling something unusual before there is a usual is
    /// how a new user gets flagged for their second ever grocery shop.
    @Test("too little history means nothing is called unusual")
    func shortHistoryIsSilent() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [1_000, 1_000], current: 9_000)
        ])
        #expect(anomalies.isEmpty)
    }

    /// One holiday month drags a mean upward and then hides the next spike behind it.
    @Test("the baseline is the median, so one past outlier does not mask a spike")
    func medianResistsAPastOutlier() {
        // Mean is 6,000 and would swallow a 9,000 current; median is 2,000 and flags it.
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [2_000, 2_000, 20_000, 2_000], current: 9_000)
        ])

        #expect(anomalies.count == 1)
        #expect(anomalies.first?.typicalAmount == 2_000)
    }

    /// Tripling a small category is arithmetically a spike and practically noise.
    @Test("a proportionally large but tiny spike is ignored")
    func tinySpikeIsIgnored() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [40, 50, 45], current: 150)
        ])
        #expect(anomalies.isEmpty)
    }

    @Test("ordinary month-to-month variation is not an anomaly")
    func ordinaryVariationIsSilent() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [5_000, 5_200, 4_800], current: 5_600)
        ])
        #expect(anomalies.isEmpty)
    }

    @Test("spending less than usual is never flagged")
    func underspendingIsNotAnAnomaly() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [5_000, 5_000, 5_000], current: 100)
        ])
        #expect(anomalies.isEmpty)
    }

    /// A category with no prior spend has no norm, so its first purchase is not a spike.
    @Test("a brand new category is not an anomaly")
    func firstEverSpendIsSilent() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(prior: [0, 0, 0], current: 7_000)
        ])
        #expect(anomalies.isEmpty)
    }

    @Test("the biggest surprise leads")
    func resultsAreOrderedByDifference() {
        let anomalies = SpendingAnomalyEngine.evaluate([
            series(name: "Small", prior: [1_000, 1_000, 1_000], current: 3_000),
            series(name: "Large", prior: [2_000, 2_000, 2_000], current: 20_000),
        ])

        #expect(anomalies.map(\.categoryName) == ["Large", "Small"])
    }

    @Test("an even number of prior periods averages the two middle values")
    func medianOfEvenCount() {
        #expect(SpendingAnomalyEngine.median([100, 200, 300, 400]) == 250)
        #expect(SpendingAnomalyEngine.median([10, 20, 30]) == 20)
        #expect(SpendingAnomalyEngine.median([]) == 0)
    }

    @Test("an empty input produces nothing rather than crashing")
    func emptyInputIsEmpty() {
        #expect(SpendingAnomalyEngine.evaluate([]).isEmpty)
    }
}
