import SwiftUI
import VittoraCore

@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool
    var isLocked: Bool
    var isOnboardingComplete: Bool
    var selectedTab: AppTab
    var isLoading: Bool
    var isUITesting: Bool
    /// When true, UI tests exercise real background/foreground app-lock policy despite `--uitesting`.
    var exercisesAppLockPolicy: Bool
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
    /// Typed global command requests (keyboard shortcuts, dashboard quick actions).
    private(set) var pendingCommand: AppCommandRequest?

    init(
        isAuthenticated: Bool = false,
        isLocked: Bool = false,
        isOnboardingComplete: Bool = KeychainService.syncLoadBool(forKey: AppUserDefaults.KeychainKey.onboardingComplete),
        selectedTab: AppTab = .dashboard,
        isLoading: Bool = false,
        isUITesting: Bool = false,
        exercisesAppLockPolicy: Bool = false,
        isPrivacyShieldVisible: Bool = false,
        pendingNotificationDeepLink: VittoraNotificationDeepLink? = nil
    ) {
        self.isAuthenticated = isAuthenticated
        self.isLocked = isLocked
        self.isOnboardingComplete = isOnboardingComplete
        self.selectedTab = selectedTab
        self.isLoading = isLoading
        self.isUITesting = isUITesting
        self.exercisesAppLockPolicy = exercisesAppLockPolicy
        self.isPrivacyShieldVisible = isPrivacyShieldVisible
        self.pendingNotificationDeepLink = pendingNotificationDeepLink
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
    }

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

    /// Routes to the Splits tab and queues a group detail navigation (K3 share-out).
    func openSplitGroup(from url: URL) {
        guard let groupID = SplitGroupDeepLink.groupID(from: url) else { return }
        pendingSplitGroupID = groupID
        selectedTab = .splits
    }

    func clearPendingSplitGroupID() {
        pendingSplitGroupID = nil
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
