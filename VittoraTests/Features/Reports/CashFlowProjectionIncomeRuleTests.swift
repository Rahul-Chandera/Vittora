import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// A salary rule is not a cost.
///
/// `RecurrenceDateMath.totalAmount` summed every active rule regardless of
/// direction, on the stated assumption that "active recurring rules are
/// expense-only". That is false — the seeded $6,400 salary is one — so the
/// Cash Flow report projected
///
///     6,400 - (8,265.49 + 2,696.01) = -$4,561.50 a month
///
/// and told the user they were heading for **-$27,369** over six months, while
/// the Cash Flow Forecast screen projected **+$1,650** a month from the same
/// ledger. Two reports, opposite signs.
///
/// Same root cause as the "Monthly Spend" figure on the recurring list: a rule
/// carries no transaction type, so direction has to come from its category.
@Suite("Cash flow projection excludes income rules")
struct CashFlowProjectionIncomeRuleTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func rule(_ amount: Decimal, category: UUID?, next: Date) -> RecurringRuleEntity {
        RecurringRuleEntity(
            frequency: .monthly,
            nextDate: next,
            templateAmount: amount,
            templateCategoryID: category,
            templateAccountID: UUID()
        )
    }

    /// The regression, at the level of the utility that got it wrong.
    @Test("an income rule is not counted as a recurring expense")
    func incomeRuleIsNotAnExpense() {
        let salaryCategory = UUID()
        let start = date(2026, 10, 1)
        let end = date(2026, 11, 1)

        let salary = rule(6_400, category: salaryCategory, next: date(2026, 10, 30))
        let rent = rule(1_850, category: UUID(), next: date(2026, 10, 1))

        let total = RecurrenceDateMath.totalAmount(
            for: [salary, rent],
            in: start..<end,
            incomeCategoryIDs: [salaryCategory],
            calendar: calendar
        )

        #expect(total == 1_850)
    }

    /// Without the income IDs every rule counts — which is exactly why the
    /// parameter is required rather than defaulted.
    @Test("with no income IDs supplied the salary counts, which is why the parameter is required")
    func emptySetCountsEverything() {
        let start = date(2026, 10, 1)
        let end = date(2026, 11, 1)

        let salary = rule(6_400, category: UUID(), next: date(2026, 10, 30))
        let rent = rule(1_850, category: UUID(), next: date(2026, 10, 1))

        let total = RecurrenceDateMath.totalAmount(
            for: [salary, rent],
            in: start..<end,
            incomeCategoryIDs: [],
            calendar: calendar
        )

        #expect(total == 8_250)
    }

    /// A rule with no category cannot be shown to be income, and every caller
    /// of this wants a cost.
    @Test("a rule with no category still counts as an expense")
    func uncategorisedRuleCountsAsExpense() {
        let start = date(2026, 10, 1)
        let end = date(2026, 11, 1)

        let total = RecurrenceDateMath.totalAmount(
            for: [rule(500, category: nil, next: date(2026, 10, 5))],
            in: start..<end,
            incomeCategoryIDs: [UUID()],
            calendar: calendar
        )

        #expect(total == 500)
    }
}
