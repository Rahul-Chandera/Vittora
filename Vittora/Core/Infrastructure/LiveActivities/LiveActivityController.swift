import Foundation
import OSLog
import VittoraCore
#if os(iOS)
// @preconcurrency: ActivityKit's `Activity` is not Sendable-annotated, so under
// Swift 6 region isolation every `await activity.update(...)` from this
// MainActor class is reported as sending a non-Sendable value. The calls are
// safe — the activity never leaves the main actor — and the import attribute is
// the targeted way to say so, rather than restructuring around a framework gap.
@preconcurrency import ActivityKit
#endif

/// Starts, updates and ends Vittora's Live Activities (M3.3).
///
/// Wrapped rather than called directly from views for three reasons: ActivityKit
/// is iOS-only and the app also builds for macOS; every entry point has to cope
/// with the user having Live Activities switched off; and the shopping session's
/// arithmetic is worth testing without a device.
@MainActor
final class LiveActivityController {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "liveactivity")

    static let shared = LiveActivityController()

    #if os(iOS)
    private var shoppingActivity: Activity<ShoppingSessionAttributes>?
    private var billActivity: Activity<BillCountdownAttributes>?
    #endif

    /// False when the user has switched Live Activities off for Vittora, or on a
    /// platform without them. Callers use this to hide the entry point rather
    /// than offering a button that silently does nothing.
    var areActivitiesEnabled: Bool {
        #if os(iOS)
        ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        false
        #endif
    }

    var hasActiveShoppingSession: Bool {
        #if os(iOS)
        shoppingActivity != nil
        #else
        false
        #endif
    }

    // MARK: - Shopping session (M3.3.1 / M3.3.2)

    @discardableResult
    func startShoppingSession(
        name: String,
        currencyCode: String,
        budgetName: String? = nil,
        budgetRemaining: Decimal? = nil
    ) -> Bool {
        #if os(iOS)
        guard areActivitiesEnabled else { return false }
        // Starting a second session would leave the first orphaned on the Lock
        // Screen with a total that never moves again.
        guard shoppingActivity == nil else { return false }

        let attributes = ShoppingSessionAttributes(
            sessionName: name,
            currencyCode: currencyCode,
            budgetName: budgetName
        )
        let state = ShoppingSessionAttributes.ContentState(
            runningTotal: 0,
            itemCount: 0,
            budgetRemaining: budgetRemaining,
            isOverBudget: (budgetRemaining ?? 0) < 0
        )

        do {
            shoppingActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            return true
        } catch {
            Self.logger.error("Could not start shopping Live Activity: \(error.localizedDescription, privacy: .public)")
            return false
        }
        #else
        return false
        #endif
    }

    func updateShoppingSession(addingAmount amount: Decimal) async {
        #if os(iOS)
        guard let current = shoppingActivity?.content.state else { return }
        let next = Self.applying(amount: amount, to: current)
        // Optional chaining, not a local binding: under Swift 6 region isolation
        // binding the Activity and then awaiting counts as sending it.
        await shoppingActivity?.update(ActivityContent(state: next, staleDate: nil))
        #endif
    }

    func endShoppingSession() async {
        #if os(iOS)
        guard shoppingActivity != nil else { return }
        // .immediate rather than .after: the session is over the moment the user
        // says so, and leaving it on the Lock Screen invites a stale total being
        // read as current.
        await shoppingActivity?.end(nil, dismissalPolicy: .immediate)
        shoppingActivity = nil
        #endif
    }

    // MARK: - Bill countdown (M3.3.3)

    /// How long ActivityKit keeps a Live Activity: 8 hours active, then up to 4
    /// more on the Lock Screen before the system removes it.
    nonisolated static let liveActivityLifetime: TimeInterval = 12 * 60 * 60

    /// The moment a bill countdown counts down to, or nil when one can't be
    /// offered for this date right now.
    ///
    /// The target is the START of the due day: that is when the bill becomes
    /// due, and it is the day Vittora records the payment, so a countdown to
    /// anything later would still be running after the transaction appeared.
    ///
    /// Only offered once the due moment is within the Live Activity lifetime.
    /// A countdown started days out would be removed by the system long before
    /// it reached zero, which reads as the feature breaking.
    nonisolated static func billCountdownDueMoment(
        nextDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        let due = calendar.startOfDay(for: nextDate)
        let remaining = due.timeIntervalSince(now)
        guard remaining > 0, remaining <= liveActivityLifetime else { return nil }
        return due
    }

    /// The recurring rule whose countdown is on the Lock Screen, if any.
    var activeBillRuleID: UUID? {
        #if os(iOS)
        currentBillActivity?.attributes.ruleID
        #else
        nil
        #endif
    }

    #if os(iOS)
    /// The running countdown, adopting one left over from a previous launch —
    /// otherwise a relaunch would lose track of it and "Mark as Paid" would
    /// have nothing to end.
    private var currentBillActivity: Activity<BillCountdownAttributes>? {
        if let billActivity, billActivity.activityState == .active { return billActivity }
        billActivity = Activity<BillCountdownAttributes>.activities.first { $0.activityState == .active }
        return billActivity
    }
    #endif

    /// Starts a countdown, replacing any other bill's. One at a time: two
    /// countdowns would compete for the single Dynamic Island slot.
    @discardableResult
    func startBillCountdown(
        billName: String,
        amount: Decimal,
        currencyCode: String,
        dueDate: Date,
        ruleID: UUID? = nil
    ) async -> Bool {
        #if os(iOS)
        guard areActivitiesEnabled else { return false }
        // A bill already due needs paying, not counting down to.
        guard dueDate > .now else { return false }

        if currentBillActivity != nil {
            await billActivity?.end(nil, dismissalPolicy: .immediate)
            billActivity = nil
        }

        do {
            billActivity = try Activity.request(
                attributes: BillCountdownAttributes(
                    billName: billName,
                    amount: amount,
                    currencyCode: currencyCode,
                    dueDate: dueDate,
                    ruleID: ruleID
                ),
                content: ActivityContent(
                    state: BillCountdownAttributes.ContentState(isPaid: false),
                    // The system dismisses it once the bill is due; there is
                    // nothing to count down to after that.
                    staleDate: dueDate
                )
            )
            return true
        } catch {
            Self.logger.error("Could not start bill Live Activity: \(error.localizedDescription, privacy: .public)")
            return false
        }
        #else
        return false
        #endif
    }

    func markBillPaid() async {
        #if os(iOS)
        guard currentBillActivity != nil else { return }
        // Show "paid" briefly rather than vanishing mid-glance, then dismiss.
        await billActivity?.update(
            ActivityContent(state: BillCountdownAttributes.ContentState(isPaid: true), staleDate: nil)
        )
        await billActivity?.end(nil, dismissalPolicy: .after(.now.addingTimeInterval(4)))
        billActivity = nil
        #endif
    }
}

#if os(iOS)
extension LiveActivityController {
    /// The session arithmetic, separated so it can be tested without ActivityKit.
    ///
    /// `budgetRemaining` is decremented by the amount rather than recomputed from
    /// the period, because the widget must never disagree with what the user just
    /// saw the app add. It is allowed to go negative — clamping it at zero would
    /// hide exactly the overspend the feature exists to surface.
    nonisolated static func applying(
        amount: Decimal,
        to state: ShoppingSessionAttributes.ContentState
    ) -> ShoppingSessionAttributes.ContentState {
        let remaining = state.budgetRemaining.map { $0 - amount }
        return ShoppingSessionAttributes.ContentState(
            runningTotal: state.runningTotal + amount,
            itemCount: state.itemCount + 1,
            budgetRemaining: remaining,
            isOverBudget: (remaining ?? 0) < 0,
            lastUpdated: .now
        )
    }
}
#endif
