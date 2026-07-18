import Foundation

/// Annualized monthly equivalents for subscription audit (plan M2.8.7 / R2).
///
/// Uses fixed calendar factors (weekly ×52/12, yearly ÷12, etc.) rather than
/// days-in-current-month so month-to-month totals stay stable.
public enum SubscriptionCostNormalization {
    /// Normalize a recurring amount to its average monthly cost.
    public nonisolated static func monthlyEquivalent(
        amount: Decimal,
        frequency: RecurrenceFrequency
    ) -> Decimal {
        switch frequency {
        case .daily:
            return amount * 365 / 12
        case .weekly:
            return amount * 52 / 12
        case .biweekly:
            return amount * 26 / 12
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .yearly:
            return amount / 12
        case .custom(let days):
            guard days > 0 else { return 0 }
            return amount * 365 / (Decimal(days) * 12)
        }
    }

    /// Annual cost from the monthly equivalent (monthly × 12).
    public nonisolated static func annualEquivalent(
        amount: Decimal,
        frequency: RecurrenceFrequency
    ) -> Decimal {
        monthlyEquivalent(amount: amount, frequency: frequency) * 12
    }
}
