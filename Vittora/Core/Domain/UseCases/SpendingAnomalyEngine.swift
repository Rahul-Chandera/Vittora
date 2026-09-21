import Foundation
import VittoraCore

/// A category spending well outside its own recent norm (M3.6.4).
///
/// "Its own" is the point: there is no population baseline here, only what this user
/// usually spends on this category. A flag means "this is unlike your last few months",
/// never "this is too much".
nonisolated struct SpendingAnomaly: Identifiable, Sendable, Equatable {
    nonisolated var id: UUID { categoryID }
    nonisolated let categoryID: UUID
    nonisolated let categoryName: String
    /// What this period cost.
    nonisolated let currentAmount: Decimal
    /// The middle of the prior periods, which is what "usual" means here.
    nonisolated let typicalAmount: Decimal
    nonisolated let priorPeriodCount: Int

    nonisolated var difference: Decimal { currentAmount - typicalAmount }

    /// How many times the usual amount this period reached. Zero when there is no usual
    /// amount to compare against, rather than a division by zero.
    nonisolated var multiple: Double {
        guard typicalAmount > 0 else { return 0 }
        return (currentAmount as NSDecimalNumber).doubleValue
            / (typicalAmount as NSDecimalNumber).doubleValue
    }
}

/// Flags categories spending unlike their own recent history.
///
/// Rules, not a model. Three guards exist because each one, missing, produces a flag the
/// user would rightly ignore — and an advisory surface that cries wolf gets dismissed
/// wholesale, taking the useful flags with it:
///
/// - **Minimum history.** Two months is not a pattern. With fewer prior periods than
///   `minimumPriorPeriods` nothing is called unusual, because there is no "usual" yet.
/// - **Median, not mean.** One holiday month drags a mean upward and then hides the next
///   spike behind it. The median of prior periods is what the user would call typical.
/// - **A material absolute difference.** Tripling a 40-rupee category is arithmetically a
///   spike and practically noise, so a flag also has to clear `minimumDifference`.
enum SpendingAnomalyEngine {
    nonisolated static let minimumPriorPeriods = 3
    /// 1.5x the usual amount. Below this, ordinary month-to-month variation trips it.
    nonisolated static let multipleThreshold = Decimal(string: "1.5") ?? 1
    /// Ignores spikes too small to act on, expressed in the user's own currency.
    nonisolated static let minimumDifference: Decimal = 500

    struct CategorySeries: Sendable, Equatable {
        nonisolated let categoryID: UUID
        nonisolated let categoryName: String
        /// Oldest first, excluding the current period.
        nonisolated let priorAmounts: [Decimal]
        nonisolated let currentAmount: Decimal

        nonisolated init(
            categoryID: UUID,
            categoryName: String,
            priorAmounts: [Decimal],
            currentAmount: Decimal
        ) {
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.priorAmounts = priorAmounts
            self.currentAmount = currentAmount
        }
    }

    nonisolated static func evaluate(
        _ series: [CategorySeries],
        minimumDifference: Decimal = minimumDifference
    ) -> [SpendingAnomaly] {
        series.compactMap { entry -> SpendingAnomaly? in
            guard entry.priorAmounts.count >= minimumPriorPeriods else { return nil }
            let typical = median(entry.priorAmounts)
            guard typical > 0 else { return nil }
            guard entry.currentAmount > typical * multipleThreshold else { return nil }
            guard entry.currentAmount - typical >= minimumDifference else { return nil }

            return SpendingAnomaly(
                categoryID: entry.categoryID,
                categoryName: entry.categoryName,
                currentAmount: entry.currentAmount,
                typicalAmount: typical,
                priorPeriodCount: entry.priorAmounts.count
            )
        }
        // Biggest surprise first, by how far above usual rather than by raw size: a
        // category that doubled matters more than a large one that stayed flat.
        .sorted { $0.difference > $1.difference }
    }

    /// Middle value, averaging the two middles on an even count. Decimal throughout — a
    /// median of money is money.
    nonisolated static func median(_ values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
}
