import SwiftUI
import VittoraCore
#if os(iOS)
import WidgetKit
#endif

@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool
    var isLocked: Bool
    var isOnboardingComplete: Bool
    var selectedTab: AppTab
    var isLoading: Bool
    var isUITesting: Bool
    /// When true, screens stop advertising Continuity activities (iCloud signed out).
    /// Observable so `HandoffAdvertisementModifier` re-evaluates immediately.
    var isHandoffAdvertisingSuspended: Bool
    /// When true, UI tests exercise real background/foreground app-lock policy despite `--uitesting`.
    var exercisesAppLockPolicy: Bool
    /// True when the on-disk store failed to open and the app is running on an
    /// in-memory recovery container (the disk store is untouched and unopened).
    let isRecoveryMode: Bool
    /// Monotonic per-domain counters bumped when persisted data in that domain changes.
    private(set) var transactionsRefreshVersion = 0
    private(set) var accountsRefreshVersion = 0
    private(set) var budgetsRefreshVersion = 0
    private(set) var categoriesRefreshVersion = 0
    private(set) var payeesRefreshVersion = 0
    private(set) var debtRefreshVersion = 0
    private(set) var recurringRefreshVersion = 0
    private(set) var splitsRefreshVersion = 0
    private(set) var savingsRefreshVersion = 0
    var isPrivacyShieldVisible: Bool
    /// Set when the user opens the app from a local notification tap (C1).
    var pendingNotificationDeepLink: VittoraNotificationDeepLink?
    /// Split group to open from a shared `vittora://splits/group/…` link (K3).
    var pendingSplitGroupID: UUID?
    /// Quick-add destination from `vittora://add?type=…` (W4). Survives App Lock —
    /// consumed after unlock when the main UI mounts.
    var pendingQuickAdd: QuickAddDeepLink.Destination?
    /// Transaction detail from Spotlight / `vittora://transaction/<id>` (P2). Survives
    /// App Lock like W4 — consumed after unlock when Transactions mounts.
    var pendingTransactionDetailID: UUID?
    /// Transaction list filter from Handoff (`vittora://transactions?…`).
    var pendingTransactionListFilter: HandoffDeepLink.ListFilter?
    /// Budget detail from Handoff / notification-style deep link.
    var pendingBudgetDetailID: UUID?
    /// Account detail from Handoff (`vittora://account/<id>`).
    var pendingAccountDetailID: UUID?
    /// Report detail from Handoff (`vittora://report/<type>?…`).
    var pendingReportHandoff: PendingReportHandoff?
    /// Unsaved transaction form draft from Handoff (identifiers + field values only).
    var pendingTransactionDraft: HandoffDeepLink.Draft?
    /// UI-test surface for W5 intent result verification (`--ui-test-show-spending-intent-result`).
    var uiTestIntentResultMessage: String?
    /// WatchConnectivity commit failures (queued expense rejected on the phone).
    var watchBridgeErrorMessage: String?
    /// Spotlight reindex hook (set by the app shell). Avoids Core Spotlight in unit tests.
    @ObservationIgnored
    var onTransactionsChangedForSpotlight: (() -> Void)?
    /// Typed global command requests (keyboard shortcuts, dashboard quick actions).
    private(set) var pendingCommand: AppCommandRequest?

    init(
        isAuthenticated: Bool = false,
        isLocked: Bool = false,
        isOnboardingComplete: Bool = KeychainService.syncLoadBool(forKey: AppUserDefaults.KeychainKey.onboardingComplete),
        selectedTab: AppTab = .dashboard,
        isLoading: Bool = false,
        isUITesting: Bool = false,
        isHandoffAdvertisingSuspended: Bool = false,
        exercisesAppLockPolicy: Bool = false,
        isRecoveryMode: Bool = false,
        isPrivacyShieldVisible: Bool = false,
        pendingNotificationDeepLink: VittoraNotificationDeepLink? = nil
    ) {
        self.isAuthenticated = isAuthenticated
        self.isLocked = isLocked
        self.isOnboardingComplete = isOnboardingComplete
        self.selectedTab = selectedTab
        self.isLoading = isLoading
        self.isUITesting = isUITesting
        self.isHandoffAdvertisingSuspended = isHandoffAdvertisingSuspended
        self.exercisesAppLockPolicy = exercisesAppLockPolicy
        self.isRecoveryMode = isRecoveryMode
        self.isPrivacyShieldVisible = isPrivacyShieldVisible
        self.pendingNotificationDeepLink = pendingNotificationDeepLink
    }

    /// Whether Continuity activities may be advertised for the current screen.
    func shouldAdvertiseHandoff(isActive: Bool = true) -> Bool {
        isActive && !isUITesting && !isHandoffAdvertisingSuspended
    }

    func refreshVersion(for domain: DataRefreshDomain) -> Int {
        switch domain {
        case .transactions: transactionsRefreshVersion
        case .accounts: accountsRefreshVersion
        case .budgets: budgetsRefreshVersion
        case .categories: categoriesRefreshVersion
        case .payees: payeesRefreshVersion
        case .debt: debtRefreshVersion
        case .recurring: recurringRefreshVersion
        case .splits: splitsRefreshVersion
        case .savings: savingsRefreshVersion
        }
    }

    /// Combined token for dashboard aggregates (transactions, accounts, budgets, recurring).
    var dashboardRefreshToken: DashboardRefreshToken {
        DashboardRefreshToken(
            transactions: transactionsRefreshVersion,
            accounts: accountsRefreshVersion,
            budgets: budgetsRefreshVersion,
            recurring: recurringRefreshVersion
        )
    }

    func notifyChanged(_ domain: DataRefreshDomain) {
        switch domain {
        case .transactions: transactionsRefreshVersion &+= 1
        case .accounts: accountsRefreshVersion &+= 1
        case .budgets: budgetsRefreshVersion &+= 1
        case .categories: categoriesRefreshVersion &+= 1
        case .payees: payeesRefreshVersion &+= 1
        case .debt: debtRefreshVersion &+= 1
        case .recurring: recurringRefreshVersion &+= 1
        case .splits: splitsRefreshVersion &+= 1
        case .savings: savingsRefreshVersion &+= 1
        }
        #if os(iOS)
        if domain == .transactions || domain == .budgets {
            WidgetCenter.shared.reloadAllTimelines()
            watchBridge?.pushSnapshot()
        }
        #endif
        if domain == .transactions {
            onTransactionsChangedForSpotlight?()
        }
    }

    #if os(iOS)
    /// Set once after DI is ready; pushes snapshots on transaction/budget changes.
    weak var watchBridge: WatchBridgeService?
    #endif

    func notifyChanged(_ domains: some Sequence<DataRefreshDomain>) {
        for domain in domains {
            notifyChanged(domain)
        }
    }

    func hasAnyRefresh(in domains: some Sequence<DataRefreshDomain>) -> Bool {
        domains.contains { refreshVersion(for: $0) > 0 }
    }

    func request(_ command: AppCommand) {
        pendingCommand = AppCommandRequest(command: command, id: UUID())
    }

    func clearPendingCommand() {
        pendingCommand = nil
    }

    /// Routes the user to the tab/feature associated with a notification deep link.
    func openFromNotification(_ deepLink: VittoraNotificationDeepLink) {
        pendingNotificationDeepLink = deepLink
        switch deepLink.destination {
        case .budgets, .budgetDetail:
            selectedTab = .budgets
        case .accountDetail:
            selectedTab = .dashboard
        case .debt:
            selectedTab = .debt
        case .transactions, .recurring:
            selectedTab = .transactions
        case .savings:
            selectedTab = .savings
        }
    }

    /// Routes `vittora://` URLs: Handoff / quick-add (W4), transaction Spotlight (P2),
    /// or split-group (K3). Unknown/malformed links are ignored so the app opens
    /// without crashing.
    func openFromURL(_ url: URL) {
        if let route = HandoffDeepLink.route(from: url) {
            openFromHandoffRoute(route)
            return
        }
        // Legacy quick-add / Spotlight hosts that HandoffDeepLink didn't claim.
        if QuickAddDeepLink.isQuickAddURL(url) {
            if let destination = QuickAddDeepLink.destination(from: url) {
                openQuickAdd(destination)
            }
            return
        }
        if TransactionSpotlightDeepLink.isTransactionURL(url) {
            if let id = TransactionSpotlightDeepLink.transactionID(from: url) {
                openFromSpotlight(transactionID: id)
            }
            return
        }
        openSplitGroup(from: url)
    }

    /// Continues a Handoff activity through the same URL routing path.
    func openFromHandoffActivity(_ activity: NSUserActivity) {
        if activity.activityType == AppHandoff.mainType {
            if let raw = activity.userInfo?[AppHandoff.tabKey] as? String,
               let tab = AppTab(rawValue: raw) {
                selectedTab = tab
            }
            return
        }
        guard let route = AppHandoff.route(from: activity) else { return }
        openFromURL(HandoffDeepLink.url(for: route))
    }

    /// Applies a Handoff route (also used after encode → decode in tests).
    func openFromHandoffRoute(_ route: HandoffDeepLink.Route) {
        switch route {
        case .transactionList(let filter):
            pendingTransactionListFilter = filter
            selectedTab = .transactions
        case .transactionDetail(let id):
            openFromSpotlight(transactionID: id)
        case .budgetsList:
            pendingBudgetDetailID = nil
            selectedTab = .budgets
        case .budgetDetail(let id):
            pendingBudgetDetailID = id
            selectedTab = .budgets
        case .accountsList:
            pendingAccountDetailID = nil
            selectedTab = .dashboard
        case .accountDetail(let id):
            pendingAccountDetailID = id
            selectedTab = .dashboard
        case .reportDetail(let type, let start, let end):
            pendingReportHandoff = PendingReportHandoff(typeRaw: type, start: start, end: end)
            selectedTab = .reports
        case .transactionDraft(let draft):
            applyTransactionDraft(draft)
        }
    }

    /// Queues transaction detail navigation from a Spotlight tap (CSSearchableItem
    /// or `vittora://transaction/…`). Survives App Lock — resolve after unlock.
    func openFromSpotlight(transactionID: UUID) {
        pendingTransactionDetailID = transactionID
        selectedTab = .transactions
    }

    func clearPendingTransactionDetailID() {
        pendingTransactionDetailID = nil
    }

    func clearPendingTransactionListFilter() {
        pendingTransactionListFilter = nil
    }

    func clearPendingBudgetDetailID() {
        pendingBudgetDetailID = nil
    }

    func clearPendingAccountDetailID() {
        pendingAccountDetailID = nil
    }

    func clearPendingReportHandoff() {
        pendingReportHandoff = nil
    }

    func clearPendingTransactionDraft() {
        pendingTransactionDraft = nil
    }

    /// Routes to the Splits tab and queues a group detail navigation (K3 share-out).
    func openSplitGroup(from url: URL) {
        guard let groupID = SplitGroupDeepLink.groupID(from: url) else { return }
        pendingSplitGroupID = groupID
        selectedTab = .splits
    }

    func clearPendingSplitGroupID() {
        pendingSplitGroupID = nil
    }

    func clearPendingQuickAdd() {
        pendingQuickAdd = nil
    }

    private func openQuickAdd(_ destination: QuickAddDeepLink.Destination) {
        pendingQuickAdd = destination
        selectedTab = .dashboard
        request(.presentQuickAdd(destination))
    }

    private func applyTransactionDraft(_ draft: HandoffDeepLink.Draft) {
        let hasFieldValues = draft.amount != nil
            || draft.note != nil
            || draft.categoryID != nil
            || draft.accountID != nil
            || draft.date != nil
        if hasFieldValues {
            pendingTransactionDraft = draft
            let destination = QuickAddDeepLink.Destination(rawValue: draft.type ?? QuickAddDeepLink.Destination.expense.rawValue)
                ?? .expense
            openQuickAdd(destination)
            return
        }
        guard let typeRaw = draft.type,
              let destination = QuickAddDeepLink.Destination(rawValue: typeRaw)
        else {
            return
        }
        openQuickAdd(destination)
    }

    enum AppTab: String, CaseIterable, Identifiable, Sendable {
        case dashboard
        case transactions
        case budgets
        case reports
        case debt
        case splits
        case tax
        case savings
        case settings

        nonisolated var id: String { rawValue }

        nonisolated var title: String {
            switch self {
            case .dashboard:    String(localized: "Dashboard")
            case .transactions: String(localized: "Transactions")
            case .budgets:      String(localized: "Budgets")
            case .reports:      String(localized: "Reports")
            case .debt:         String(localized: "Debt")
            case .splits:       String(localized: "Splits")
            case .tax:          String(localized: "Tax")
            case .savings:      String(localized: "Savings")
            case .settings:     String(localized: "Settings")
            }
        }

        nonisolated var systemImage: String {
            switch self {
            case .dashboard:    "chart.pie.fill"
            case .transactions: "list.bullet.rectangle.fill"
            case .budgets:      "target"
            case .reports:      "chart.bar.fill"
            case .debt:         "hand.point.up.left.fill"
            case .splits:       "person.3.fill"
            case .tax:          "building.columns.fill"
            case .savings:      "star.circle.fill"
            case .settings:     "gearshape.fill"
            }
        }
    }
}

/// Report continuation payload (type + optional period). Identifiers / dates only.
struct PendingReportHandoff: Equatable, Sendable {
    var typeRaw: String
    var start: Date?
    var end: Date?

    var reportType: ReportType? {
        ReportType(rawValue: typeRaw)
    }

    var dateRange: ClosedRange<Date>? {
        guard let start, let end, start <= end else { return nil }
        return start...end
    }
}
