import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Month-end projection (M3.2.2) and what-if scenarios (M3.2.5).
///
/// Both are rules-based arithmetic per the plan's scope note. These tests pin
/// the guards that stop either becoming misleading.
@Suite("SpendingProjectionEngine")
@MainActor
struct SpendingProjectionEngineTests {

    private let engine = SpendingProjectionEngine()
    private func d(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    /// 10 days in, £500 spent, 30-day month -> £50/day -> £1,500.
    @Test("projects month end from the current daily rate")
    func projectsLinearly() throws {
        let p = try #require(engine.project(
            spentSoFar: 500, elapsedDays: 10, totalDays: 30, priorMonthTotals: []
        ))
        #expect(p.dailyRate == 50)
        #expect(p.projectedTotal == 1_500)
    }

    /// On day 2 a single large shop projects to a catastrophic month. Nothing is
    /// offered until the month has enough shape to extrapolate from.
    @Test("refuses to project before the month has enough shape")
    func refusesEarlyMonth() {
        #expect(engine.project(spentSoFar: 400, elapsedDays: 2, totalDays: 30, priorMonthTotals: []) == nil)
        #expect(engine.project(spentSoFar: 400, elapsedDays: 4, totalDays: 30, priorMonthTotals: []) == nil)
        #expect(engine.project(spentSoFar: 400, elapsedDays: 5, totalDays: 30, priorMonthTotals: []) != nil)
    }

    @Test("no spending yields no projection rather than zero")
    func noSpendNoProjection() {
        #expect(engine.project(spentSoFar: 0, elapsedDays: 10, totalDays: 30, priorMonthTotals: []) == nil)
    }

    /// Median, so one unusual month does not move what "typical" means.
    @Test("typical month is the median of prior months")
    func typicalIsMedian() throws {
        let p = try #require(engine.project(
            spentSoFar: 500, elapsedDays: 10, totalDays: 30,
            priorMonthTotals: [1_000, 1_100, 5_000]   // one outlier
        ))
        #expect(p.typicalMonth == 1_100)
        #expect(p.differenceFromTypical == 400)
        #expect(p.isAboveTypical)
    }

    /// Without history there is no basis for comparison, and comparing against
    /// zero would report every month as an overspend.
    @Test("no history means no comparison, not a comparison with zero")
    func noHistoryNoComparison() throws {
        let p = try #require(engine.project(
            spentSoFar: 500, elapsedDays: 10, totalDays: 30, priorMonthTotals: []
        ))
        #expect(p.typicalMonth == nil)
        #expect(p.differenceFromTypical == nil)
        #expect(p.isAboveTypical == false)
    }

    @Test("a full month projects to what was actually spent")
    func fullMonth() throws {
        let p = try #require(engine.project(
            spentSoFar: 900, elapsedDays: 30, totalDays: 30, priorMonthTotals: []
        ))
        #expect(p.projectedTotal == 900)
    }

    @Test("elapsed days beyond the month length is rejected")
    func rejectsImpossibleInput() {
        #expect(engine.project(spentSoFar: 900, elapsedDays: 31, totalDays: 30, priorMonthTotals: []) == nil)
        #expect(engine.project(spentSoFar: 900, elapsedDays: 10, totalDays: 0, priorMonthTotals: []) == nil)
    }

    /// The estimate is stated as an extrapolation, with what it misses.
    @Test("caveats name the method and what it omits")
    func caveatsStated() {
        let text = SpendingProjectionEngine.caveats.joined(separator: " ")
        #expect(text.contains("straight-line"))
        #expect(text.contains("Bills"))
    }
}

@Suite("WhatIfScenarioEngine")
@MainActor
struct WhatIfScenarioEngineTests {

    private let engine = WhatIfScenarioEngine()
    private func d(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    /// £200 typical, cut 20% -> £40/month, £480/year.
    @Test("computes the monthly and annual value of a reduction")
    func computesSaving() throws {
        let s = try #require(engine.scenario(
            categoryName: "Dining out", monthlyAmounts: [200, 200, 200], reductionPercent: 20
        ))
        #expect(s.baselineMonthly == 200)
        #expect(s.monthlySaving == 40)
        #expect(s.annualSaving == 480)
        #expect(s.newMonthly == 160)
    }

    /// The annual figure is exactly twelve times the monthly one shown above it;
    /// re-deriving it could make the two disagree on screen.
    @Test("annual is exactly twelve times the monthly figure")
    func annualAgreesWithMonthly() throws {
        let s = try #require(engine.scenario(
            categoryName: "Coffee", monthlyAmounts: [d("33.33"), d("33.33"), d("100.00")], reductionPercent: 15
        ))
        #expect(s.annualSaving == s.monthlySaving * 12)
    }

    @Test("baseline is the median, so one unusual month does not set the plan")
    func baselineIsMedian() throws {
        let s = try #require(engine.scenario(
            categoryName: "Dining out", monthlyAmounts: [100, 120, 900], reductionPercent: 50
        ))
        #expect(s.baselineMonthly == 120)
        #expect(s.monthlySaving == 60)
    }

    /// One month of history is an outlier wearing a median's clothes; planning a
    /// year around it would be worse than offering nothing.
    @Test("too little history yields no scenario")
    func requiresHistory() {
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: [200], reductionPercent: 20) == nil)
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: [], reductionPercent: 20) == nil)
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: [200, 200], reductionPercent: 20) != nil)
    }

    @Test("a percentage outside 0 to 100 is rejected")
    func rejectsBadPercent() {
        let amounts: [Decimal] = [200, 200]
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: amounts, reductionPercent: 0) == nil)
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: amounts, reductionPercent: -10) == nil)
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: amounts, reductionPercent: 101) == nil)
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: amounts, reductionPercent: 100) != nil)
    }

    @Test("a category that costs nothing yields no scenario")
    func zeroBaseline() {
        #expect(engine.scenario(categoryName: "X", monthlyAmounts: [0, 0, 0], reductionPercent: 20) == nil)
    }

    /// Cutting everything leaves nothing, and saves the whole baseline.
    @Test("a 100% reduction saves the entire baseline")
    func fullReduction() throws {
        let s = try #require(engine.scenario(
            categoryName: "X", monthlyAmounts: [150, 150], reductionPercent: 100
        ))
        #expect(s.monthlySaving == 150)
        #expect(s.newMonthly == 0)
    }

    /// The scenario reports how much history it rests on, so the user can judge it.
    @Test("the scenario says how many months it is based on")
    func reportsBaselineMonths() throws {
        let s = try #require(engine.scenario(
            categoryName: "X", monthlyAmounts: [100, 100, 100, 100], reductionPercent: 10
        ))
        #expect(s.baselineMonths == 4)
    }

    @Test("caveats state it is based on past spending, not a plan")
    func caveatsStated() {
        let text = WhatIfScenarioEngine.caveats.joined(separator: " ")
        #expect(text.contains("typically cost"))
        #expect(text.contains("stays the same"))
    }
}
