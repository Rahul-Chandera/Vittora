import Foundation
import VittoraCore

/// Monthly financial health score (M3.2.4).
///
/// Rules-based and deterministic, per the plan's scope note: calculations stay
/// rules-based, and AI is reserved for summarisation, categorisation and
/// suggestions. Nothing here is a model, and nothing here is advice — every
/// component reports the figures it was computed from so the user can see why
/// the number is what it is, rather than being handed a verdict.
///
/// The three components are the ones the plan names: budget adherence, savings
/// rate, and debt ratio.
nonisolated struct FinancialHealthScoreEngine: Sendable {

    /// Scores are 0–100. Deliberately not a letter grade or a verdict word:
    /// "poor" is a judgement about the person, a number with its inputs shown
    /// is a measurement they can check.
    nonisolated struct Component: Sendable, Identifiable, Hashable {
        nonisolated let id: Kind
        nonisolated let score: Int
        /// The figures behind the score, so the number is auditable.
        nonisolated let detail: String

        nonisolated enum Kind: String, Sendable, Hashable, CaseIterable {
            case budgetAdherence
            case savingsRate
            case debtRatio
        }
    }

    nonisolated struct Result: Sendable {
        /// Nil when nothing could be measured at all — a new user with no
        /// budgets, no income and no debts gets no score rather than a zero,
        /// which would read as a failing grade for having just arrived.
        nonisolated let overallScore: Int?
        nonisolated let components: [Component]
        /// Components that could not be measured, and why. Surfaced rather than
        /// hidden: a score built from one of three inputs means something quite
        /// different from one built from all three.
        nonisolated let unmeasured: [String]

        nonisolated var measuredCount: Int { components.count }
    }

    /// What the score needs. Passed in rather than fetched so the engine stays
    /// pure and the arithmetic is testable without a store.
    nonisolated struct Inputs: Sendable {
        nonisolated let monthlyIncome: Decimal
        nonisolated let monthlyExpenses: Decimal
        /// Active budgets for the period, with their spend.
        nonisolated let budgets: [BudgetEntity]
        /// Outstanding debt the user owes, net of what has been settled.
        nonisolated let outstandingDebt: Decimal

        nonisolated init(
            monthlyIncome: Decimal,
            monthlyExpenses: Decimal,
            budgets: [BudgetEntity],
            outstandingDebt: Decimal
        ) {
            self.monthlyIncome = monthlyIncome
            self.monthlyExpenses = monthlyExpenses
            self.budgets = budgets
            self.outstandingDebt = outstandingDebt
        }
    }

    nonisolated func score(_ inputs: Inputs) -> Result {
        var components: [Component] = []
        var unmeasured: [String] = []

        if let budget = budgetAdherence(inputs) {
            components.append(budget)
        } else {
            unmeasured.append(String(localized: "No active budgets, so budget adherence was not scored."))
        }

        if let savings = savingsRate(inputs) {
            components.append(savings)
        } else {
            unmeasured.append(String(localized: "No income recorded this month, so savings rate was not scored."))
        }

        if let debt = debtRatio(inputs) {
            components.append(debt)
        } else {
            unmeasured.append(String(localized: "No income recorded this month, so debt ratio was not scored."))
        }

        // Equal weighting, and stated as a choice. Weighting one component above
        // the others would embed a judgement about what matters most in someone
        // else's finances, which is exactly what the scope note rules out.
        //
        // Components that could not be measured are EXCLUDED rather than scored
        // zero. Scoring an absent budget as zero would punish a user for not
        // using a feature; scoring it 100 would flatter them for the same.
        guard !components.isEmpty else {
            return Result(overallScore: nil, components: [], unmeasured: unmeasured)
        }
        let total = components.reduce(0) { $0 + $1.score }
        let overall = Int((Double(total) / Double(components.count)).rounded())

        return Result(
            overallScore: overall,
            components: components.sorted { $0.id.rawValue < $1.id.rawValue },
            unmeasured: unmeasured
        )
    }
}

// MARK: - Components

extension FinancialHealthScoreEngine {

    /// The share of active budgets not overspent, as a percentage.
    ///
    /// Counting budgets rather than amounts, deliberately: one large budget
    /// slightly over would otherwise swamp five small ones kept comfortably,
    /// and the question this answers is "am I keeping to my budgets", not
    /// "how much did I overspend in total".
    nonisolated func budgetAdherence(_ inputs: Inputs) -> Component? {
        guard !inputs.budgets.isEmpty else { return nil }

        let withinBudget = inputs.budgets.filter { !$0.isOverBudget }.count
        let total = inputs.budgets.count
        let score = Int((Double(withinBudget) / Double(total) * 100).rounded())

        return Component(
            id: .budgetAdherence,
            score: score,
            detail: String(localized: "\(withinBudget) of \(total) budgets within limit.")
        )
    }

    /// Income kept rather than spent, as a percentage of income.
    ///
    /// Capped at 100 and floored at 0: a month where expenses exceeded income
    /// produces a negative rate, which is real information, but a negative
    /// component would drag the overall score below the 0–100 range it claims.
    /// The detail line still reports the true rate.
    nonisolated func savingsRate(_ inputs: Inputs) -> Component? {
        guard inputs.monthlyIncome > 0 else { return nil }

        let saved = inputs.monthlyIncome - inputs.monthlyExpenses
        let rate = (saved / inputs.monthlyIncome * 100)
        let clamped = max(0, min(100, (rate as NSDecimalNumber).doubleValue))

        let percentText = Self.percent(rate)
        return Component(
            id: .savingsRate,
            score: Int(clamped.rounded()),
            detail: saved < 0
                ? String(localized: "Spent more than you earned this month (\(percentText)).")
                : String(localized: "Kept \(percentText) of income this month.")
        )
    }

    /// Outstanding debt measured against monthly income, inverted so that less
    /// debt scores higher.
    ///
    /// Debt equal to or above twelve months of income scores zero; no debt
    /// scores 100. Twelve months is a stated yardstick rather than a derived
    /// one — there is no universal threshold, and picking one silently would
    /// pass off a convention as a fact.
    nonisolated func debtRatio(_ inputs: Inputs) -> Component? {
        guard inputs.monthlyIncome > 0 else { return nil }

        let annualIncome = inputs.monthlyIncome * 12
        let debt = max(0, inputs.outstandingDebt)
        let ratio = (debt / annualIncome as NSDecimalNumber).doubleValue
        let score = Int((max(0, min(1, 1 - ratio)) * 100).rounded())

        return Component(
            id: .debtRatio,
            score: score,
            detail: debt == 0
                ? String(localized: "No outstanding debt recorded.")
                : String(localized: "Outstanding debt is \(Self.percent(debt / annualIncome * 100)) of a year's income.")
        )
    }

    nonisolated static func percent(_ value: Decimal) -> String {
        let rounded = value.rounded(scale: 0)
        return "\((rounded as NSDecimalNumber).intValue)%"
    }
}
