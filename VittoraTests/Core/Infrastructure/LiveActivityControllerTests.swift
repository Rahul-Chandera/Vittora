#if os(iOS)
import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Shopping-session arithmetic (M3.3.1 / M3.3.2).
///
/// ActivityKit itself cannot run in a unit test — requesting an activity needs a
/// real device with Live Activities enabled — so the arithmetic was separated
/// out and is tested here. What ActivityKit does with the state is device-only
/// and is stated as such in the PR.
@Suite("LiveActivityController shopping session state")
@MainActor
struct LiveActivityControllerTests {

    private func state(
        total: Decimal = 0,
        items: Int = 0,
        remaining: Decimal? = nil,
        over: Bool = false
    ) -> ShoppingSessionAttributes.ContentState {
        ShoppingSessionAttributes.ContentState(
            runningTotal: total,
            itemCount: items,
            budgetRemaining: remaining,
            isOverBudget: over
        )
    }

    private func decimal(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    @Test("adding an item accumulates the total and the count")
    func accumulates() {
        let first = LiveActivityController.applying(amount: decimal("12.50"), to: state())
        #expect(first.runningTotal == decimal("12.50"))
        #expect(first.itemCount == 1)

        let second = LiveActivityController.applying(amount: decimal("7.25"), to: first)
        #expect(second.runningTotal == decimal("19.75"))
        #expect(second.itemCount == 2)
    }

    @Test("budget remaining is decremented by each item")
    func decrementsBudget() {
        let next = LiveActivityController.applying(
            amount: decimal("30.00"),
            to: state(remaining: decimal("100.00"))
        )
        #expect(next.budgetRemaining == decimal("70.00"))
        #expect(next.isOverBudget == false)
    }

    /// Going negative is the point — clamping at zero would hide exactly the
    /// overspend the feature exists to surface.
    @Test("remaining budget goes negative rather than clamping at zero")
    func goesNegative() {
        let next = LiveActivityController.applying(
            amount: decimal("120.00"),
            to: state(remaining: decimal("100.00"))
        )
        #expect(next.budgetRemaining == decimal("-20.00"))
        #expect(next.isOverBudget)
    }

    /// The flag is computed once, in the app, so the widget renders it rather
    /// than re-deriving it and possibly disagreeing.
    @Test("over-budget flips exactly when remaining crosses below zero")
    func overBudgetBoundary() {
        let exact = LiveActivityController.applying(
            amount: decimal("100.00"),
            to: state(remaining: decimal("100.00"))
        )
        #expect(exact.budgetRemaining == 0)
        #expect(exact.isOverBudget == false, "spending exactly the budget is not over it")

        let over = LiveActivityController.applying(amount: decimal("0.01"), to: exact)
        #expect(over.isOverBudget)
    }

    /// A user with no budget still gets a running total.
    @Test("a session without a budget tracks the total and never reports over-budget")
    func noBudget() {
        let next = LiveActivityController.applying(amount: decimal("45.00"), to: state())
        #expect(next.runningTotal == decimal("45.00"))
        #expect(next.budgetRemaining == nil)
        #expect(next.isOverBudget == false)
    }

    /// Decimal arithmetic, not Double — money that drifts by a cent across a
    /// dozen items would show a total the user can see is wrong.
    @Test("repeated additions stay exact")
    func staysExact() {
        var current = state(remaining: decimal("10.00"))
        for _ in 0..<10 {
            current = LiveActivityController.applying(amount: decimal("0.10"), to: current)
        }
        #expect(current.runningTotal == decimal("1.00"))
        #expect(current.budgetRemaining == decimal("9.00"))
        #expect(current.itemCount == 10)
    }

    @Test("lastUpdated advances so the widget can show staleness")
    func timestampAdvances() {
        let before = Date()
        let next = LiveActivityController.applying(amount: decimal("1.00"), to: state())
        #expect(next.lastUpdated >= before)
    }

    /// The state crosses a process boundary into the widget extension, so it has
    /// to survive a Codable round trip — a mismatch there does not fail to build,
    /// it silently fails to decode and the activity never appears.
    @Test("content state survives a Codable round trip")
    func codableRoundTrip() throws {
        let original = state(total: decimal("19.75"), items: 2, remaining: decimal("-5.00"), over: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShoppingSessionAttributes.ContentState.self, from: data)
        #expect(decoded.runningTotal == original.runningTotal)
        #expect(decoded.itemCount == original.itemCount)
        #expect(decoded.budgetRemaining == original.budgetRemaining)
        #expect(decoded.isOverBudget == original.isOverBudget)
    }

    @Test("bill countdown state survives a Codable round trip")
    func billCodableRoundTrip() throws {
        let original = BillCountdownAttributes.ContentState(isPaid: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillCountdownAttributes.ContentState.self, from: data)
        #expect(decoded.isPaid)
    }

    // MARK: - Bill countdown window (M3.3.3)

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ iso: String) -> Date {
        (try? Date(iso, strategy: .iso8601)) ?? .distantPast
    }

    /// The target is midnight at the start of the due day — the rule's time of
    /// day is whenever it was created, and means nothing to the user.
    @Test("the countdown targets the start of the due day")
    func countdownTargetsStartOfDueDay() {
        let due = LiveActivityController.billCountdownDueMoment(
            nextDate: date("2026-10-05T15:47:00Z"),
            now: date("2026-10-04T20:00:00Z"),
            calendar: utc
        )
        #expect(due == date("2026-10-05T00:00:00Z"))
    }

    /// ActivityKit removes an activity after 12 hours at most, so a countdown
    /// started earlier would vanish before it reached zero.
    @Test("not offered until the due moment is within the Live Activity lifetime")
    func countdownNotOfferedTooEarly() {
        let next = date("2026-10-05T09:00:00Z")
        #expect(LiveActivityController.billCountdownDueMoment(
            nextDate: next, now: date("2026-10-04T11:59:00Z"), calendar: utc
        ) == nil)
        #expect(LiveActivityController.billCountdownDueMoment(
            nextDate: next, now: date("2026-10-04T12:00:00Z"), calendar: utc
        ) != nil)
    }

    @Test("not offered once the bill is due")
    func countdownNotOfferedWhenDue() {
        #expect(LiveActivityController.billCountdownDueMoment(
            nextDate: date("2026-10-05T09:00:00Z"),
            now: date("2026-10-05T00:00:00Z"),
            calendar: utc
        ) == nil)
    }

    /// Attributes cross into the widget extension, and a countdown started by
    /// the previous build has no `ruleID`. It must still decode, or the running
    /// activity silently disappears on update.
    @Test("bill attributes without a rule id still decode")
    func billAttributesDecodeWithoutRuleID() throws {
        let original = BillCountdownAttributes(
            billName: "Rent", amount: 1_200, currencyCode: "USD",
            dueDate: date("2026-10-05T00:00:00Z")
        )
        let decoded = try JSONDecoder().decode(
            BillCountdownAttributes.self, from: JSONEncoder().encode(original)
        )
        #expect(decoded.ruleID == nil)
        #expect(decoded.billName == "Rent")

        let ruleID = UUID()
        var withRule = original
        withRule.ruleID = ruleID
        let decodedWithRule = try JSONDecoder().decode(
            BillCountdownAttributes.self, from: JSONEncoder().encode(withRule)
        )
        #expect(decodedWithRule.ruleID == ruleID)
    }

    // MARK: - Shopping budget options (M3.3.2)

    @Test("budgets are named by category, or Overall, and deleted categories are dropped")
    func shoppingBudgetOptions() {
        let groceries = CategoryEntity(name: "Groceries", icon: "cart", type: .expense)
        let overall = BudgetEntity(amount: 2_000, spent: 500)
        let food = BudgetEntity(amount: 400, spent: 150, categoryID: groceries.id)
        let orphan = BudgetEntity(amount: 100, categoryID: UUID())

        let options = ShoppingBudgetOption.options(
            budgets: [overall, food, orphan],
            categories: [groceries]
        )

        #expect(options.map(\.id) == [food.id, overall.id])
        #expect(options.first?.remaining == 250)
        #expect(options.last?.name == String(localized: "Overall"))
    }
}
#endif
