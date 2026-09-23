import Foundation
import VittoraCore

/// Month-end spending projection (M3.2.2).
///
/// Rules-based, per the plan's scope note. The plan phrases this feature as
/// "ML-powered", but the note that governs the module says calculations stay
/// rules-based and AI is reserved for summarisation, categorisation and
/// suggestions. A run-rate extrapolation is what this is, and it is described
/// as one rather than dressed up as a prediction.
nonisolated struct SpendingProjectionEngine: Sendable {

    /// Below this many days elapsed, a run rate is arithmetic rather than
    /// information: on day 2 a single large shop projects to a catastrophic
    /// month. Nothing is offered until the month has enough shape to extrapolate
    /// from.
    nonisolated static let minimumElapsedDays = 5

    nonisolated struct Projection: Sendable, Equatable {
        nonisolated let spentSoFar: Decimal
        /// Straight-line to month end from the current daily rate.
        nonisolated let projectedTotal: Decimal
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
    }

    /// Nil when the month is too young to extrapolate from, or when nothing has
    /// been spent. Both are "no answer" rather than a misleading zero.
    nonisolated func project(
        spentSoFar: Decimal,
        elapsedDays: Int,
        totalDays: Int,
        priorMonthTotals: [Decimal]
    ) -> Projection? {
        guard elapsedDays >= Self.minimumElapsedDays,
              elapsedDays <= totalDays,
              totalDays > 0,
              spentSoFar > 0
        else { return nil }

        let rate = spentSoFar / Decimal(elapsedDays)
        let projected = (rate * Decimal(totalDays)).rounded(scale: 2)

        // Median, not mean: one unusual month should not move what "typical"
        // means, which is the same reasoning SpendingAnomalyEngine uses.
        let typical = priorMonthTotals.isEmpty
            ? nil
            : SpendingAnomalyEngine.median(priorMonthTotals)

        return Projection(
            spentSoFar: spentSoFar,
            projectedTotal: projected,
            elapsedDays: elapsedDays,
            totalDays: totalDays,
            typicalMonth: typical
        )
    }

    /// What the projection does NOT account for, stated so the number is not
    /// read as more than it is. Surfaced in the UI beside the figure.
    nonisolated static var caveats: [String] {
        [
            String(localized: "A straight-line estimate from what you have spent so far this month."),
            String(localized: "Bills that fall later in the month are not counted separately, so the estimate can move when they land."),
        ]
    }
}
