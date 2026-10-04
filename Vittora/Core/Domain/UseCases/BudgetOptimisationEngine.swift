import Foundation
import VittoraCore

/// Something the user's own budget history shows about a limit (M3.6.5).
///
/// An observation, never an instruction. Each one states what happened and what the user
/// typically spent; it does not tell them what to set. A budget deliberately kept tight to
/// force a habit is not a mistake, and the app cannot tell that apart from one that is
/// simply wrong — so it reports and lets the user decide.
nonisolated struct BudgetObservation: Identifiable, Sendable, Equatable {
    nonisolated enum Kind: Sendable, Equatable {
        /// Every recent period finished well under the limit.
        case consistentlyUnderSpent
        /// Every recent period went over.
        case consistentlyOverSpent
        /// Nothing was spent against it at all.
        case unused
    }

    nonisolated var id: UUID { budgetID }
    nonisolated let budgetID: UUID
    nonisolated let categoryName: String
    nonisolated let limit: Decimal
    /// The middle of the prior periods — what this budget actually costs in practice.
    nonisolated let typicalSpend: Decimal
    nonisolated let periodCount: Int
    nonisolated let kind: Kind

    /// Unused headroom at the typical spend. Negative when the budget is habitually
    /// exceeded, which is the number that makes an over-spend concrete.
    nonisolated var difference: Decimal { limit - typicalSpend }
}

/// Reads a budget's own history and reports what it shows.
///
/// Rules, not a model, and the same three guards the anomaly engine needs — for the same
/// reason. An advisory surface that fires on thin evidence gets dismissed wholesale, and
/// takes the useful observations with it.
enum BudgetOptimisationEngine {
    nonisolated static let minimumPriorPeriods = 3
    /// Under this share of the limit, every period, before "consistently under" is fair.
    nonisolated static let underSpendShare = Decimal(string: "0.6") ?? 1
    /// Headroom too small to be worth a card.
    nonisolated static let minimumDifference: Decimal = 500

    struct BudgetSeries: Sendable, Equatable {
        nonisolated let budgetID: UUID
        nonisolated let categoryName: String
        nonisolated let limit: Decimal
        /// Spend per prior period, oldest first. Excludes the period in progress: judging a
        /// budget on a month that is half over would call every budget under-spent.
        nonisolated let priorSpend: [Decimal]

        nonisolated init(
            budgetID: UUID,
            categoryName: String,
            limit: Decimal,
            priorSpend: [Decimal]
        ) {
            self.budgetID = budgetID
            self.categoryName = categoryName
            self.limit = limit
            self.priorSpend = priorSpend
        }
    }

    nonisolated static func evaluate(
        _ series: [BudgetSeries],
        minimumDifference: Decimal = minimumDifference
    ) -> [BudgetObservation] {
        series.compactMap { entry -> BudgetObservation? in
            guard entry.priorSpend.count >= minimumPriorPeriods, entry.limit > 0 else { return nil }
            let typical = SpendingAnomalyEngine.median(entry.priorSpend)

            func observation(_ kind: BudgetObservation.Kind) -> BudgetObservation {
                BudgetObservation(
                    budgetID: entry.budgetID,
                    categoryName: entry.categoryName,
                    limit: entry.limit,
                    typicalSpend: typical,
                    periodCount: entry.priorSpend.count,
                    kind: kind
                )
            }

            if entry.priorSpend.allSatisfy({ $0 == 0 }) {
                return observation(.unused)
            }
            // Every period, not the median: one quiet month inside an otherwise tight
            // budget is not a pattern, and reporting it as one is how this surface starts
            // being ignored.
            if entry.priorSpend.allSatisfy({ $0 <= entry.limit * underSpendShare }),
               entry.limit - typical >= minimumDifference {
                return observation(.consistentlyUnderSpent)
            }
            if entry.priorSpend.allSatisfy({ $0 > entry.limit }) {
                return observation(.consistentlyOverSpent)
            }
            return nil
        }
        // Over-spends first — a budget being breached every month is the one worth acting
        // on — then by how much headroom is going unused.
        .sorted { lhs, rhs in
            if lhs.kind == rhs.kind { return abs(lhs.difference) > abs(rhs.difference) }
            return rank(lhs.kind) < rank(rhs.kind)
        }
    }

    nonisolated private static func rank(_ kind: BudgetObservation.Kind) -> Int {
        switch kind {
        case .consistentlyOverSpent: 0
        case .unused: 1
        case .consistentlyUnderSpent: 2
        }
    }
}
