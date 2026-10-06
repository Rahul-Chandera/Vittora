import Foundation
import VittoraCore

/// Month-end spending projection (M3.2.2).
///
/// Rules-based, per the plan's scope note. The plan phrases this feature as
/// "ML-powered", but the note that governs the module says calculations stay
/// rules-based and AI is reserved for summarisation, categorisation and
/// suggestions. It is arithmetic over the user's own history, described as
/// that rather than dressed up as a prediction.
///
/// Two methods. With enough history it takes what has been spent so far and
/// adds what the REST of the month has typically cost (`.pattern`). A rent paid
/// on the 1st is then counted once: the straight line multiplied it across the
/// month, which on 5 October projected $18,291 against a typical $2,417. Bills
/// that usually land later are in the typical remainder. Without that history
/// it falls back to the straight line (`.straightLine`).
nonisolated struct SpendingProjectionEngine: Sendable {

    /// Below this many days elapsed, a run rate is arithmetic rather than
    /// information: on day 2 a single large shop projects to a catastrophic
    /// month. Nothing is offered until the month has enough shape to extrapolate
    /// from.
    nonisolated static let minimumElapsedDays = 5

    /// Whole prior months needed before the rest of the month is estimated from
    /// history. Fewer, and one odd month would set the estimate.
    nonisolated static let minimumPatternMonths = 3

    nonisolated enum Method: Sendable, Equatable {
        /// Spent so far plus the median of what the rest of earlier months cost.
        case pattern
        /// Current daily rate extended to month end.
        case straightLine
    }

    nonisolated struct Projection: Sendable, Equatable {
        nonisolated let spentSoFar: Decimal
        /// Estimated month-end total; how it was reached is `method`.
        nonisolated let projectedTotal: Decimal
        nonisolated let method: Method
        nonisolated let elapsedDays: Int
        nonisolated let totalDays: Int
        /// The median of prior whole months, when enough exist to have one.
        nonisolated let typicalMonth: Decimal?

        nonisolated var dailyRate: Decimal {
            guard elapsedDays > 0 else { return 0 }
            return spentSoFar / Decimal(elapsedDays)
        }

        /// How the projection compares with a typical month. Nil when there is
        /// no basis for comparison, rather than comparing against zero.
        nonisolated var differenceFromTypical: Decimal? {
            typicalMonth.map { projectedTotal - $0 }
        }

        nonisolated var isAboveTypical: Bool {
            guard let difference = differenceFromTypical else { return false }
            return difference > 0
        }

        /// What this estimate does and does not account for, matching its method.
        nonisolated var caveats: [String] {
            method == .pattern ? SpendingProjectionEngine.patternCaveats : SpendingProjectionEngine.caveats
        }
    }

    /// Nil when nothing has been spent, or when only the straight line is
    /// available and the month is too young for it. Both are "no answer" rather
    /// than a misleading zero.
    ///
    /// - Parameter priorMonthRemainders: for each prior whole month, what was
    ///   spent on the days AFTER `elapsedDays`. Months with nothing then count
    ///   as zero, so they belong in the list.
    nonisolated func project(
        spentSoFar: Decimal,
        elapsedDays: Int,
        totalDays: Int,
        priorMonthTotals: [Decimal],
        priorMonthRemainders: [Decimal] = []
    ) -> Projection? {
        guard elapsedDays >= 1,
              elapsedDays <= totalDays,
              totalDays > 0,
              spentSoFar > 0
        else { return nil }

        let method: Method
        let projected: Decimal
        if priorMonthRemainders.count >= Self.minimumPatternMonths {
            // Median, for the same reason as the typical month below. No early-
            // month guard: spent-so-far plus a typical remainder is sensible on
            // day one, which is exactly when the straight line is not.
            method = .pattern
            projected = (spentSoFar + SpendingAnomalyEngine.median(priorMonthRemainders)).rounded(scale: 2)
        } else {
            guard elapsedDays >= Self.minimumElapsedDays else { return nil }
            method = .straightLine
            projected = (spentSoFar / Decimal(elapsedDays) * Decimal(totalDays)).rounded(scale: 2)
        }

        // Median, not mean: one unusual month should not move what "typical"
        // means, which is the same reasoning SpendingAnomalyEngine uses.
        let typical = priorMonthTotals.isEmpty
            ? nil
            : SpendingAnomalyEngine.median(priorMonthTotals)

        return Projection(
            spentSoFar: spentSoFar,
            projectedTotal: projected,
            method: method,
            elapsedDays: elapsedDays,
            totalDays: totalDays,
            typicalMonth: typical
        )
    }

    /// The `.pattern` estimate, stated so the number is not read as more than it is.
    nonisolated static var patternCaveats: [String] {
        [
            String(localized: "What you have spent so far, plus what the rest of the month has usually cost you."),
            String(localized: "A large bill already paid, like rent, is counted once rather than spread across the month."),
        ]
    }

    /// What the straight-line projection does NOT account for, stated so the
    /// number is not read as more than it is. Surfaced in the UI beside the figure.
    nonisolated static var caveats: [String] {
        [
            String(localized: "A straight-line estimate from what you have spent so far this month."),
            String(localized: "Bills that fall later in the month are not counted separately, so the estimate can move when they land."),
        ]
    }
}
