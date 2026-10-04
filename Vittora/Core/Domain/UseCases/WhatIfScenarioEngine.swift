import Foundation
import VittoraCore

/// "What-if" spending scenarios (M3.2.5).
///
/// Pure arithmetic on the user's own figures: reduce a category by some share,
/// and see what that would have come to over a month and a year.
///
/// Deliberately not advice. The plan's scope note rules out financial advice,
/// so this answers "what would that have been worth" and never "you should cut
/// this". The category and the percentage are both the user's choice; the
/// engine supplies only the multiplication.
nonisolated struct WhatIfScenarioEngine: Sendable {

    nonisolated struct Scenario: Sendable, Equatable {
        nonisolated let categoryName: String
        /// What the category typically costs in a month.
        nonisolated let baselineMonthly: Decimal
        /// The share the user asked to model, 0–100.
        nonisolated let reductionPercent: Decimal
        nonisolated let monthlySaving: Decimal
        nonisolated let annualSaving: Decimal
        /// What the category would cost per month under the scenario.
        nonisolated let newMonthly: Decimal
        /// How many months the baseline was drawn from, so the user can judge
        /// how much to trust it.
        nonisolated let baselineMonths: Int
    }

    /// Fewer than this many months and the baseline is one or two data points
    /// wearing a median's clothes.
    nonisolated static let minimumBaselineMonths = 2

    /// Nil when there is not enough history to form a baseline, or when the
    /// percentage is outside 0–100. A scenario built on one month would invite
    /// the user to plan a year around a single outlier.
    nonisolated func scenario(
        categoryName: String,
        monthlyAmounts: [Decimal],
        reductionPercent: Decimal
    ) -> Scenario? {
        guard monthlyAmounts.count >= Self.minimumBaselineMonths,
              reductionPercent > 0,
              reductionPercent <= 100
        else { return nil }

        // Median rather than mean, for the same reason the anomaly engine uses
        // it: one unusual month should not set the baseline the user plans from.
        let baseline = SpendingAnomalyEngine.median(monthlyAmounts)
        guard baseline > 0 else { return nil }

        let monthly = (baseline * reductionPercent / 100).rounded(scale: 2)
        // Twelve times the monthly figure, not a re-derived annual total: the
        // user is being shown the consequence of the monthly number above it,
        // and the two must agree exactly.
        let annual = (monthly * 12).rounded(scale: 2)

        return Scenario(
            categoryName: categoryName,
            baselineMonthly: baseline,
            reductionPercent: reductionPercent,
            monthlySaving: monthly,
            annualSaving: annual,
            newMonthly: (baseline - monthly).rounded(scale: 2),
            baselineMonths: monthlyAmounts.count
        )
    }

    /// Stated beside every scenario. It is a projection of the user's own past
    /// spending, not a plan and not a recommendation.
    nonisolated static var caveats: [String] {
        [
            String(localized: "Based on what this category has typically cost you, not on a plan."),
            String(localized: "Assumes the rest of your spending stays the same."),
        ]
    }
}
