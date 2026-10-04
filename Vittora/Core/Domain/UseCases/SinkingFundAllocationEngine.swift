import Foundation
import VittoraCore

/// Sinking funds — several savings goals sharing one account (M2.5.5).
///
/// Goals already carry a `linkedAccountID`, but nothing ever read it back. That
/// left the defining sinking-fund problem unhandled: three goals can each claim
/// £600 of a £1,000 account, every one of them shows as on track, and the money
/// is only counted once in reality. This engine is what notices.
///
/// It is deliberately pure — goals and accounts in, a summary out — so the
/// arithmetic is testable without a store, and so the same numbers can feed a
/// view, a warning, or a report without being recomputed differently in each.
nonisolated struct SinkingFundAllocationEngine: Sendable {

    /// One account and every goal earmarking money in it.
    nonisolated struct AccountAllocation: Sendable, Identifiable, Hashable {
        nonisolated var id: UUID { accountID }
        nonisolated let accountID: UUID
        nonisolated let accountName: String
        nonisolated let currencyCode: String
        /// What the account actually holds.
        nonisolated let accountBalance: Decimal
        /// Goals pointing at this account, richest claim first.
        nonisolated let goals: [GoalClaim]

        /// The sum of what every goal says it has saved here.
        nonisolated var totalAllocated: Decimal {
            goals.reduce(Decimal(0)) { $0 + $1.allocatedAmount }
        }

        /// Balance not spoken for. Negative when the goals over-claim, and that
        /// is the number worth surfacing — it is the money that does not exist.
        nonisolated var unallocated: Decimal { accountBalance - totalAllocated }

        nonisolated var isOverAllocated: Bool { unallocated < 0 }

        /// How much the claims exceed the balance by. Zero when they do not.
        nonisolated var overAllocationAmount: Decimal { max(0, -unallocated) }

        /// Share of the balance already spoken for, capped for display at 1.
        /// Over-allocation is reported by `isOverAllocated`, not by a bar that
        /// runs off the end.
        nonisolated var allocatedFraction: Double {
            guard accountBalance > 0 else { return totalAllocated > 0 ? 1 : 0 }
            let fraction = (totalAllocated as NSDecimalNumber).doubleValue
                / (accountBalance as NSDecimalNumber).doubleValue
            return min(1, max(0, fraction))
        }
    }

    nonisolated struct GoalClaim: Sendable, Identifiable, Hashable {
        nonisolated let id: UUID
        nonisolated let name: String
        nonisolated let allocatedAmount: Decimal
        nonisolated let targetAmount: Decimal
        nonisolated let colorHex: String
        nonisolated let isEmergencyFund: Bool
    }

    /// Builds one allocation per account that has at least one goal linked to it.
    ///
    /// Accounts with no goals are omitted: this screen is about money that has
    /// been earmarked, and listing every empty account would bury the ones that
    /// matter. Goals with no linked account are omitted too — they are tracked,
    /// but they are not claiming a specific balance, so they cannot over-claim.
    nonisolated func allocations(
        goals: [SavingsGoalEntity],
        accounts: [AccountEntity]
    ) -> [AccountAllocation] {
        let accountsByID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Achieved and archived goals still hold their money, so they still
        // count against the balance. Dropping them would make an over-allocated
        // account look healthy the moment one goal completed.
        let linked = goals.filter { $0.linkedAccountID != nil }

        let grouped = Dictionary(grouping: linked) { $0.linkedAccountID ?? UUID() }

        var result: [AccountAllocation] = []
        for (accountID, goalsForAccount) in grouped {
            guard let account = accountsByID[accountID] else { continue }
            let claims = Self.claims(from: goalsForAccount)
            result.append(
                AccountAllocation(
                    accountID: account.id,
                    accountName: account.name,
                    currencyCode: account.currencyCode,
                    accountBalance: account.balance,
                    goals: claims
                )
            )
        }
        // Over-allocated accounts first — they are the ones needing action.
        return result.sorted { lhs, rhs in
            if lhs.isOverAllocated != rhs.isOverAllocated { return lhs.isOverAllocated }
            return lhs.accountName.localizedCaseInsensitiveCompare(rhs.accountName) == .orderedAscending
        }
    }

    /// Split out of `allocations` because the chained map-then-sort inside a
    /// compactMap closure defeated the type checker.
    nonisolated private static func claims(from goals: [SavingsGoalEntity]) -> [GoalClaim] {
        let mapped: [GoalClaim] = goals.map { goal in
            GoalClaim(
                id: goal.id,
                name: goal.name,
                allocatedAmount: goal.currentAmount,
                targetAmount: goal.targetAmount,
                colorHex: goal.colorHex,
                isEmergencyFund: goal.isEmergencyFund
            )
        }
        // Largest claim first, then by name so the order is stable across
        // launches rather than following dictionary order.
        return mapped.sorted { lhs, rhs in
            if lhs.allocatedAmount == rhs.allocatedAmount {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.allocatedAmount > rhs.allocatedAmount
        }
    }

    /// Accounts whose goals claim more than the balance. The screen leads with
    /// these, and they are what a warning would key off.
    nonisolated func overAllocated(
        goals: [SavingsGoalEntity],
        accounts: [AccountEntity]
    ) -> [AccountAllocation] {
        allocations(goals: goals, accounts: accounts).filter(\.isOverAllocated)
    }
}
