import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Financial health score (M3.2.4).
///
/// Rules-based and deterministic per the plan's scope note. These tests pin the
/// behaviour that keeps the score honest: what happens when something cannot be
/// measured, and that the number never silently becomes a verdict.
@Suite("FinancialHealthScoreEngine")
@MainActor
struct FinancialHealthScoreEngineTests {

    private let engine = FinancialHealthScoreEngine()

    private func d(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    private func budget(amount: Decimal, spent: Decimal) -> BudgetEntity {
        BudgetEntity(amount: amount, spent: spent)
    }

    private func inputs(
        income: Decimal = 5_000,
        expenses: Decimal = 3_000,
        budgets: [BudgetEntity] = [],
        debt: Decimal = 0
    ) -> FinancialHealthScoreEngine.Inputs {
        .init(
            monthlyIncome: income,
            monthlyExpenses: expenses,
            budgets: budgets,
            outstandingDebt: debt
        )
    }

    private func component(
        _ result: FinancialHealthScoreEngine.Result,
        _ kind: FinancialHealthScoreEngine.Component.Kind
    ) -> FinancialHealthScoreEngine.Component? {
        result.components.first { $0.id == kind }
    }

    // MARK: - Missing data

    /// A brand-new user has no budgets, no income and no debt. Scoring that as
    /// zero would read as a failing grade for having just arrived.
    @Test("a user with nothing measurable gets no score, not zero")
    func nothingMeasurable() {
        let result = engine.score(inputs(income: 0, expenses: 0))
        #expect(result.overallScore == nil)
        #expect(result.components.isEmpty)
        #expect(result.unmeasured.count == 3)
    }

    /// Absent components are excluded rather than scored. Scoring an absent
    /// budget zero punishes a user for not using a feature; scoring it 100
    /// flatters them for the same.
    @Test("no budgets means adherence is unmeasured, not zero")
    func noBudgetsExcluded() {
        let result = engine.score(inputs(income: 5_000, expenses: 2_500))
        #expect(component(result, .budgetAdherence) == nil)
        #expect(result.unmeasured.contains { $0.contains("budget") })
        // Savings rate 50, debt ratio 100 -> 75, not 50 as it would be if the
        // missing component were scored zero and averaged in.
        #expect(result.overallScore == 75)
        #expect(result.measuredCount == 2)
    }

    @Test("no income means savings rate and debt ratio are unmeasured")
    func noIncomeExcluded() {
        let result = engine.score(
            inputs(income: 0, expenses: 500, budgets: [budget(amount: 100, spent: 50)])
        )
        #expect(component(result, .savingsRate) == nil)
        #expect(component(result, .debtRatio) == nil)
        #expect(component(result, .budgetAdherence)?.score == 100)
        #expect(result.overallScore == 100)
    }

    // MARK: - Budget adherence

    /// Counting budgets rather than amounts: one large budget slightly over
    /// should not swamp several small ones kept comfortably.
    @Test("adherence counts budgets kept, not amounts overspent")
    func adherenceCountsBudgets() {
        let result = engine.score(inputs(budgets: [
            budget(amount: 10_000, spent: 10_500),   // one big overspend
            budget(amount: 100, spent: 50),
            budget(amount: 100, spent: 50),
            budget(amount: 100, spent: 50),
        ]))
        // 3 of 4 kept = 75, not a tiny number driven by the £500 overspend.
        #expect(component(result, .budgetAdherence)?.score == 75)
    }

    @Test("all budgets kept scores 100")
    func allBudgetsKept() {
        let result = engine.score(inputs(budgets: [
            budget(amount: 100, spent: 100),
            budget(amount: 200, spent: 10),
        ]))
        #expect(component(result, .budgetAdherence)?.score == 100)
    }

    @Test("spending exactly the budget is not over it")
    func exactBudgetIsKept() {
        let result = engine.score(inputs(budgets: [budget(amount: 100, spent: 100)]))
        #expect(component(result, .budgetAdherence)?.score == 100)
    }

    // MARK: - Savings rate

    @Test("savings rate is the share of income kept")
    func savingsRateBasic() {
        let result = engine.score(inputs(income: 4_000, expenses: 3_000))
        #expect(component(result, .savingsRate)?.score == 25)
    }

    /// Overspending is real information, but a negative component would drag
    /// the overall below the 0–100 range the score claims. It floors at zero
    /// and the detail line still says what happened.
    @Test("overspending floors the component at zero but is still described")
    func overspendingFloors() {
        let result = engine.score(inputs(income: 1_000, expenses: 1_500))
        let savings = component(result, .savingsRate)
        #expect(savings?.score == 0)
        #expect(savings?.detail.contains("more than you earned") == true)
    }

    @Test("spending nothing scores 100 rather than overflowing")
    func savingEverything() {
        let result = engine.score(inputs(income: 1_000, expenses: 0))
        #expect(component(result, .savingsRate)?.score == 100)
    }

    // MARK: - Debt ratio

    @Test("no debt scores 100")
    func noDebt() {
        let result = engine.score(inputs(debt: 0))
        #expect(component(result, .debtRatio)?.score == 100)
        #expect(component(result, .debtRatio)?.detail.contains("No outstanding debt") == true)
    }

    /// Six months of income owed is half of the twelve-month yardstick.
    @Test("debt of half a year's income scores 50")
    func halfYearDebt() {
        // 5,000/month -> 60,000/year. 30,000 owed is half.
        let result = engine.score(inputs(income: 5_000, debt: 30_000))
        #expect(component(result, .debtRatio)?.score == 50)
    }

    /// Beyond the yardstick the component floors rather than going negative.
    @Test("debt beyond a year's income floors at zero")
    func extremeDebt() {
        let result = engine.score(inputs(income: 5_000, debt: 500_000))
        #expect(component(result, .debtRatio)?.score == 0)
    }

    // MARK: - Overall

    /// Equal weighting, stated as a choice rather than hidden: weighting one
    /// component higher would embed a judgement about what matters most in
    /// someone else's finances.
    @Test("the overall score is the mean of the measured components")
    func overallIsMean() {
        let result = engine.score(inputs(
            income: 4_000,
            expenses: 3_000,                          // savings 25
            budgets: [budget(amount: 100, spent: 50)], // adherence 100
            debt: 24_000                               // 24k / 48k -> 50
        ))
        #expect(result.measuredCount == 3)
        // (100 + 25 + 50) / 3 = 58.33 -> 58
        #expect(result.overallScore == 58)
    }

    @Test("components are returned in a stable order")
    func stableOrder() {
        let a = engine.score(inputs(budgets: [budget(amount: 100, spent: 50)]))
        let b = engine.score(inputs(budgets: [budget(amount: 100, spent: 50)]))
        #expect(a.components.map(\.id) == b.components.map(\.id))
    }

    /// Every component carries the figures behind it, so the number is
    /// auditable rather than a verdict handed down.
    @Test("every component explains itself")
    func componentsExplainThemselves() {
        let result = engine.score(inputs(
            income: 4_000,
            expenses: 3_000,
            budgets: [budget(amount: 100, spent: 50)],
            debt: 1_000
        ))
        #expect(result.components.allSatisfy { !$0.detail.isEmpty })
    }

    @Test("scores never leave the 0 to 100 range")
    func alwaysInRange() {
        let extremes = [
            inputs(income: 1, expenses: 1_000_000, budgets: [budget(amount: 1, spent: 999)], debt: 9_999_999),
            inputs(income: 1_000_000, expenses: 0, budgets: [budget(amount: 999, spent: 1)], debt: 0),
        ]
        for input in extremes {
            let result = engine.score(input)
            #expect(result.components.allSatisfy { (0...100).contains($0.score) })
            if let overall = result.overallScore {
                #expect((0...100).contains(overall))
            }
        }
    }
}
