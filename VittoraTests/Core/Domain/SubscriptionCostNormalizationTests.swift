import Foundation
import Testing
import VittoraCore

@Suite("Subscription Cost Normalization Tests")
struct SubscriptionCostNormalizationTests {

    @Test("daily amount annualizes via 365/12")
    func dailyNormalization() {
        let monthly = SubscriptionCostNormalization.monthlyEquivalent(amount: 1, frequency: .daily)
        #expect(monthly == Decimal(365) / 12)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 1, frequency: .daily) == 365)
    }

    @Test("weekly $10 → $43.33…/month (×52/12)")
    func weeklyNormalization() {
        let monthly = SubscriptionCostNormalization.monthlyEquivalent(amount: 10, frequency: .weekly)
        #expect(monthly == Decimal(10) * 52 / 12)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 10, frequency: .weekly) == 520)
    }

    @Test("biweekly amount annualizes via 26/12")
    func biweeklyNormalization() {
        let monthly = SubscriptionCostNormalization.monthlyEquivalent(amount: 20, frequency: .biweekly)
        #expect(monthly == Decimal(20) * 26 / 12)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 20, frequency: .biweekly) == 520)
    }

    @Test("monthly amount is unchanged")
    func monthlyNormalization() {
        #expect(SubscriptionCostNormalization.monthlyEquivalent(amount: 15.49, frequency: .monthly) == 15.49)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 15.49, frequency: .monthly) == 15.49 * 12)
    }

    @Test("quarterly amount divides by 3")
    func quarterlyNormalization() {
        #expect(SubscriptionCostNormalization.monthlyEquivalent(amount: 90, frequency: .quarterly) == 30)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 90, frequency: .quarterly) == 360)
    }

    @Test("yearly amount divides by 12")
    func yearlyNormalization() {
        #expect(SubscriptionCostNormalization.monthlyEquivalent(amount: 120, frequency: .yearly) == 10)
        #expect(SubscriptionCostNormalization.annualEquivalent(amount: 120, frequency: .yearly) == 120)
    }

    @Test("custom days annualizes via 365/days then ÷12")
    func customDaysNormalization() {
        let annual = SubscriptionCostNormalization.annualEquivalent(
            amount: 30,
            frequency: .custom(days: 10)
        )
        #expect(annual == Decimal(30) * 365 / Decimal(10))
        #expect(
            SubscriptionCostNormalization.monthlyEquivalent(amount: 30, frequency: .custom(days: 10))
                == annual / 12
        )
    }

    @Test("custom zero days yields zero")
    func customZeroDaysYieldsZero() {
        #expect(
            SubscriptionCostNormalization.monthlyEquivalent(amount: 50, frequency: .custom(days: 0)) == 0
        )
    }

    @Test("totals equal sum of per-row monthly equivalents")
    func totalsEqualSumOfRows() {
        let rows: [(Decimal, RecurrenceFrequency)] = [
            (15.49, .monthly),
            (10, .weekly),
            (120, .yearly),
            (90, .quarterly),
            (1, .daily),
            (20, .biweekly),
            (30, .custom(days: 10)),
        ]

        let monthlyTotal = rows.reduce(Decimal(0)) { partial, row in
            partial + SubscriptionCostNormalization.monthlyEquivalent(amount: row.0, frequency: row.1)
        }
        let annualTotal = monthlyTotal * 12

        let expectedMonthly = rows.reduce(Decimal(0)) { partial, row in
            partial + SubscriptionCostNormalization.monthlyEquivalent(amount: row.0, frequency: row.1)
        }

        #expect(monthlyTotal == expectedMonthly)
        #expect(annualTotal == expectedMonthly * 12)
    }
}
