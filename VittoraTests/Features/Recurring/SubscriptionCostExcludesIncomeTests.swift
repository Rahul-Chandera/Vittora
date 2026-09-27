import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// "Monthly Spend" must not include income rules.
///
/// `CalculateSubscriptionCostUseCase` used to total every active rule
/// regardless of direction. With the seeded demo rules — salary 6,400, rent
/// 1,850, subscriptions 15.49 — the Recurring Transactions screen reported
///
///     Monthly Spend  $8,265.49 per month   $99,185.88 per year
///
/// when the actual spend is 1,865.49 a month. The subscription tracker's
/// "Monthly Spending" card read the same figure.
///
/// A rule carries no transaction type of its own, so direction has to come
/// from its category — which is why the caller supplies the income IDs.
@Suite("Subscription cost excludes income")
@MainActor
struct SubscriptionCostExcludesIncomeTests {

    private let salaryCategory = CategoryEntity(name: "Salary", icon: "banknote", type: .income)
    private let rentCategory = CategoryEntity(name: "Rent", icon: "house", type: .expense)

    private func rule(_ amount: Decimal, category: UUID?) -> RecurringRuleEntity {
        RecurringRuleEntity(
            frequency: .monthly,
            nextDate: Date(timeIntervalSince1970: 0),
            templateAmount: amount,
            templateCategoryID: category
        )
    }

    private var useCase: CalculateSubscriptionCostUseCase {
        CalculateSubscriptionCostUseCase(
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { Date(timeIntervalSince1970: 0) }
        )
    }

    /// The regression, with the exact figures from the seeded demo data.
    @Test("a salary rule is not counted as spend")
    func salaryIsExcluded() {
        let summary = useCase.execute(
            rules: [
                rule(6_400, category: salaryCategory.id),
                rule(Decimal(string: "1850")!, category: rentCategory.id),
                rule(Decimal(string: "15.49")!, category: nil),
            ],
            incomeCategoryIDs: [salaryCategory.id]
        )

        #expect(summary.monthlyCost == Decimal(string: "1865.49")!)
        #expect(summary.annualCost == Decimal(string: "22385.88")!)
    }

    /// The count sits under the same card, so it must agree with the total.
    @Test("the rule count excludes income too")
    func countExcludesIncome() {
        let summary = useCase.execute(
            rules: [
                rule(6_400, category: salaryCategory.id),
                rule(1_850, category: rentCategory.id),
            ],
            incomeCategoryIDs: [salaryCategory.id]
        )

        #expect(summary.ruleCount == 1)
    }

    /// An uncategorised rule cannot be shown to be income, and this is a
    /// spending figure — so it counts.
    @Test("a rule with no category still counts as spend")
    func uncategorisedCountsAsSpend() {
        let summary = useCase.execute(
            rules: [rule(500, category: nil)],
            incomeCategoryIDs: [salaryCategory.id]
        )

        #expect(summary.monthlyCost == 500)
        #expect(summary.ruleCount == 1)
    }

    /// Inactive rules were already excluded; that must not have regressed.
    @Test("an inactive rule is excluded whatever its category")
    func inactiveIsExcluded() {
        var inactive = rule(1_850, category: rentCategory.id)
        inactive.isActive = false

        let summary = useCase.execute(rules: [inactive], incomeCategoryIDs: [])

        #expect(summary.monthlyCost == 0)
        #expect(summary.ruleCount == 0)
    }

    /// Passing no income IDs must not resurrect the bug by accident — with the
    /// salary category unknown to the caller, the salary counts. This pins the
    /// reason the parameter is required rather than defaulted.
    @Test("with no income IDs supplied every rule counts, which is why the parameter is required")
    func emptySetCountsEverything() {
        let summary = useCase.execute(
            rules: [
                rule(6_400, category: salaryCategory.id),
                rule(1_850, category: rentCategory.id),
            ],
            incomeCategoryIDs: []
        )

        #expect(summary.monthlyCost == 8_250)
    }
}
