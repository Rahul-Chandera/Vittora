import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Predictive entry (M3.2.7). Rules-based suggestions from the user's own
/// patterns — never a decision, always overwritable.
@Suite("PredictiveEntryEngine")
@MainActor
struct PredictiveEntryEngineTests {

    private let engine = PredictiveEntryEngine()
    private let calendar = Calendar(identifier: .gregorian)

    private func date(weekday: Int, hour: Int, week: Int = 0) -> Date {
        // 2026-09-07 is a Monday (weekday 2 in Gregorian).
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 6 + weekday + (week * 7)
        components.hour = hour
        return calendar.date(from: components) ?? .now
    }

    private func obs(
        payee: UUID?, category: UUID?, amount: Decimal, weekday: Int, hour: Int, week: Int
    ) -> PredictiveEntryEngine.Observation {
        .init(payeeID: payee, categoryID: category, amount: amount, date: date(weekday: weekday, hour: hour, week: week))
    }

    // MARK: - Thresholds

    /// Two coincidences are a coincidence.
    @Test("fewer than three matching occurrences suggests nothing")
    func requiresThreeOccurrences() {
        let payee = UUID(), category = UUID()
        let history = (0..<2).map {
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: $0)
        }
        #expect(engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar) == nil)
    }

    /// A coffee at 08:12 and 08:47 is the same habit; an exact-time match would
    /// find nothing.
    @Test("matches a time window, not an exact hour")
    func matchesWindow() throws {
        let payee = UUID(), category = UUID()
        let history = [
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: 0),
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 9, week: 1),
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 7, week: 2),
        ]
        let suggestion = try #require(
            engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar)
        )
        #expect(suggestion.payeeID == payee)
        #expect(suggestion.occurrences == 3)
    }

    @Test("a different weekday does not match")
    func weekdayMatters() {
        let payee = UUID(), category = UUID()
        let history = (0..<4).map {
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: $0)
        }
        // Same hour, different weekday.
        #expect(engine.suggest(at: date(weekday: 5, hour: 8, week: 5), history: history, calendar: calendar) == nil)
    }

    // MARK: - Amount

    /// A payee whose charges vary has no "usual" amount, and filling one in is a
    /// number the user must check and correct every time.
    @Test("an inconsistent payee gets no amount suggestion")
    func inconsistentAmountDeclined() throws {
        let payee = UUID(), category = UUID()
        let history = [
            obs(payee: payee, category: category, amount: 5, weekday: 2, hour: 8, week: 0),
            obs(payee: payee, category: category, amount: 90, weekday: 2, hour: 8, week: 1),
            obs(payee: payee, category: category, amount: 400, weekday: 2, hour: 8, week: 2),
        ]
        let suggestion = try #require(
            engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar)
        )
        #expect(suggestion.payeeID == payee)
        #expect(suggestion.amount == nil, "wildly varying amounts must not produce a suggestion")
    }

    @Test("a consistent payee gets the median amount")
    func consistentAmountSuggested() throws {
        let payee = UUID(), category = UUID()
        let history = [
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: 0),
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: 1),
            obs(payee: payee, category: category, amount: 5, weekday: 2, hour: 8, week: 2),
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: 3),
        ]
        let suggestion = try #require(
            engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar)
        )
        #expect(suggestion.amount == 4)
    }

    /// Median, not mean, so one unusual charge does not set the suggestion.
    @Test("one outlier does not move the suggested amount")
    func medianResistsOutlier() {
        let amounts: [Decimal] = [4, 4, 4, 4, 100]
        #expect(PredictiveEntryEngine.consistentAmount(amounts) == 4)
    }

    @Test("too few amounts yields none")
    func tooFewAmounts() {
        #expect(PredictiveEntryEngine.consistentAmount([4, 4]) == nil)
        #expect(PredictiveEntryEngine.consistentAmount([]) == nil)
    }

    @Test("a zero median yields no amount")
    func zeroMedian() {
        #expect(PredictiveEntryEngine.consistentAmount([0, 0, 0]) == nil)
    }

    // MARK: - Most common

    /// A bare plurality across many options is not a pattern.
    @Test("a plurality below half is not treated as a pattern")
    func pluralityRejected() {
        let a = UUID(), b = UUID(), c = UUID()
        #expect(PredictiveEntryEngine.mostCommon([a, a, b, c, c]) == nil)
    }

    @Test("a clear majority wins")
    func majorityWins() {
        let a = UUID(), b = UUID()
        #expect(PredictiveEntryEngine.mostCommon([a, a, a, b]) == a)
    }

    @Test("nils are ignored rather than counted")
    func nilsIgnored() {
        let a = UUID()
        #expect(PredictiveEntryEngine.mostCommon([nil, a, a, nil, a]) == a)
        #expect(PredictiveEntryEngine.mostCommon([nil, nil]) == nil)
    }

    /// Identical data must produce the same suggestion on every launch.
    @Test("ties resolve deterministically")
    func deterministicTies() {
        let a = UUID(), b = UUID()
        let first = PredictiveEntryEngine.mostCommon([a, b])
        let second = PredictiveEntryEngine.mostCommon([b, a])
        #expect(first == second)
    }

    // MARK: - Shape

    @Test("a suggestion with nothing in it is not offered")
    func emptySuggestionNotOffered() {
        let history = (0..<4).map {
            obs(payee: nil, category: nil, amount: 0, weekday: 2, hour: 8, week: $0)
        }
        #expect(engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar) == nil)
    }

    @Test("the suggestion carries a reason rather than presenting a guess as fact")
    func carriesReason() throws {
        let payee = UUID(), category = UUID()
        let history = (0..<3).map {
            obs(payee: payee, category: category, amount: 4, weekday: 2, hour: 8, week: $0)
        }
        let suggestion = try #require(
            engine.suggest(at: date(weekday: 2, hour: 8, week: 5), history: history, calendar: calendar)
        )
        #expect(!suggestion.reason.isEmpty)
    }

    @Test("empty history suggests nothing")
    func emptyHistory() {
        #expect(engine.suggest(at: .now, history: [], calendar: calendar) == nil)
    }
}
