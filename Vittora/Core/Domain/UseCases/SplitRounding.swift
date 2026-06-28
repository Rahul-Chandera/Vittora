import Foundation

/// Shared money/percentage tolerances and allocation helpers for split expenses (A12).
enum SplitRounding {
    static let moneyScale = 2
    /// Half-cent threshold for treating a balance as settled.
    static let moneyEpsilon: Decimal = Decimal(sign: .plus, exponent: -3, significand: 5)
    /// Exact-split validation tolerance (one cent).
    static let moneyTolerance: Decimal = Decimal(sign: .plus, exponent: -2, significand: 1)
    /// Allowed deviation when percentage inputs must sum to 100.
    static let percentageTolerance: Decimal = Decimal(sign: .plus, exponent: -2, significand: 1)

    /// Allocates `amount` across members from ideal (unrounded) part amounts.
    /// Rounds all but the last share; the last absorbs the remainder. If that
    /// remainder would be negative, pulls back from earlier shares until the
    /// last is ≥ 0. Guarantees `Σ shares == amount` exactly.
    nonisolated static func allocate(
        amount: Decimal,
        memberIDs: [UUID],
        idealParts: [Decimal]
    ) -> [SplitShare] {
        guard !memberIDs.isEmpty else { return [] }
        precondition(memberIDs.count == idealParts.count)

        if memberIDs.count == 1 {
            return [SplitShare(memberID: memberIDs[0], amount: amount.rounded(scale: moneyScale))]
        }

        var roundedLeading = idealParts.dropLast().map { $0.rounded(scale: moneyScale) }
        var lastAmount = amount - roundedLeading.reduce(Decimal(0), +)

        if lastAmount < 0 {
            var deficit = -lastAmount
            for index in stride(from: roundedLeading.count - 1, through: 0, by: -1) {
                let take = min(roundedLeading[index], deficit)
                roundedLeading[index] -= take
                deficit -= take
                if deficit == 0 { break }
            }
            lastAmount = amount - roundedLeading.reduce(Decimal(0), +)
        }

        let amounts = roundedLeading + [lastAmount]
        return zip(memberIDs, amounts).map { SplitShare(memberID: $0.0, amount: $0.1) }
    }

    nonisolated static func shareTotal(_ shares: [SplitShare]) -> Decimal {
        shares.reduce(Decimal(0)) { $0 + $1.amount }
    }

    nonisolated static func sharesBalance(_ amount: Decimal, _ shares: [SplitShare]) -> Bool {
        abs(shareTotal(shares) - amount) <= moneyTolerance
    }

    nonisolated static func allSharesNonNegative(_ shares: [SplitShare]) -> Bool {
        shares.allSatisfy { $0.amount >= 0 }
    }
}
