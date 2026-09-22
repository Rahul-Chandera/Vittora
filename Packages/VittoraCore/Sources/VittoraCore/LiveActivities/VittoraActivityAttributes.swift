#if os(iOS)
import ActivityKit
#endif
import Foundation

/// Live Activity payloads (M3.3).
///
/// These live in VittoraCore because the app starts and updates an activity while
/// the widget extension renders it, and both must agree on the exact shape. A
/// mismatch does not fail to build — it fails to decode at runtime, and the
/// activity silently never appears.
///
/// Gated on `os(iOS)`, not `canImport(ActivityKit)`: the module DOES import on
/// macOS, so canImport is true there, but `ActivityAttributes` itself is marked
/// unavailable and the package fails to build. The platform check is the one
/// that actually holds.

#if os(iOS)

/// M3.3.1 shopping mode, carrying M3.3.2's budget figure in its Dynamic Island.
///
/// Budget remaining rides on the shopping session rather than being its own
/// long-running activity, deliberately. A budget period is a month, while a Live
/// Activity is designed for something bounded in hours — an always-on
/// month-long activity would be stale-dismissed by the system and would occupy
/// the user's Lock Screen for no benefit. During a shop is exactly when the
/// remaining figure is worth glancing at.
public struct ShoppingSessionAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Running total for this session only, not the period.
        public var runningTotal: Decimal
        public var itemCount: Int
        /// Remaining in the linked budget, already reduced by `runningTotal`.
        /// Optional because a user with no budget still gets a running total.
        public var budgetRemaining: Decimal?
        /// True once the session has spent past the budget, so the widget can
        /// show it without re-deriving the comparison and disagreeing with the app.
        public var isOverBudget: Bool
        public var lastUpdated: Date

        public init(
            runningTotal: Decimal,
            itemCount: Int,
            budgetRemaining: Decimal? = nil,
            isOverBudget: Bool = false,
            lastUpdated: Date = .now
        ) {
            self.runningTotal = runningTotal
            self.itemCount = itemCount
            self.budgetRemaining = budgetRemaining
            self.isOverBudget = isOverBudget
            self.lastUpdated = lastUpdated
        }
    }

    /// What the user called this shop, e.g. a store name. Empty is allowed and
    /// the widget falls back to a generic title rather than showing a blank.
    public var sessionName: String
    public var currencyCode: String
    public var startedAt: Date
    /// The budget this session counts against, if any.
    public var budgetName: String?

    public init(
        sessionName: String,
        currencyCode: String,
        startedAt: Date = .now,
        budgetName: String? = nil
    ) {
        self.sessionName = sessionName
        self.currencyCode = currencyCode
        self.startedAt = startedAt
        self.budgetName = budgetName
    }
}

/// M3.3.3 bill countdown.
///
/// The due date is in the *attributes*, not the content state, because it does
/// not change for the life of the activity. Putting it in the state would mean
/// pushing an update every time the countdown ticks; in the attributes, the
/// widget renders the countdown itself with a relative-date style and needs no
/// updates at all.
public struct BillCountdownAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Set when the bill is paid, so the activity can show a final state
        /// before it ends rather than vanishing mid-glance.
        public var isPaid: Bool
        public var lastUpdated: Date

        public init(isPaid: Bool = false, lastUpdated: Date = .now) {
            self.isPaid = isPaid
            self.lastUpdated = lastUpdated
        }
    }

    public var billName: String
    public var amount: Decimal
    public var currencyCode: String
    public var dueDate: Date

    public init(billName: String, amount: Decimal, currencyCode: String, dueDate: Date) {
        self.billName = billName
        self.amount = amount
        self.currencyCode = currencyCode
        self.dueDate = dueDate
    }
}

#endif
