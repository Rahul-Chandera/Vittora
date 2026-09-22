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
}
#endif
