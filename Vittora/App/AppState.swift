import SwiftUI

@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool
    var isLocked: Bool
    var isOnboardingComplete: Bool
    var selectedTab: AppTab
    var isLoading: Bool
    var isUITesting: Bool
    /// Monotonic per-domain counters bumped when persisted data in that domain changes.
    private var refreshVersions: [DataRefreshDomain: Int] = [:]
    var isPrivacyShieldVisible: Bool
    /// Set when the user opens the app from a local notification tap (C1).
    var pendingNotificationDeepLink: VittoraNotificationDeepLink?
    /// Typed global command requests (keyboard shortcuts, dashboard quick actions).
    private(set) var pendingCommand: AppCommandRequest?

    init(
        isAuthenticated: Bool = false,
        isLocked: Bool = false,
        isOnboardingComplete: Bool = KeychainService.syncLoadBool(forKey: AppUserDefaults.KeychainKey.onboardingComplete),
        selectedTab: AppTab = .dashboard,
        isLoading: Bool = false,
        isUITesting: Bool = false,
        isPrivacyShieldVisible: Bool = false,
        pendingNotificationDeepLink: VittoraNotificationDeepLink? = nil
    ) {
        self.isAuthenticated = isAuthenticated
        self.isLocked = isLocked
        self.isOnboardingComplete = isOnboardingComplete
        self.selectedTab = selectedTab
        self.isLoading = isLoading
        self.isUITesting = isUITesting
        self.isPrivacyShieldVisible = isPrivacyShieldVisible
        self.pendingNotificationDeepLink = pendingNotificationDeepLink
    }

    func refreshVersion(for domain: DataRefreshDomain) -> Int {
        refreshVersions[domain, default: 0]
    }

    /// Combined token for dashboard aggregates (transactions, accounts, budgets, recurring).
    var dashboardRefreshToken: DashboardRefreshToken {
        DashboardRefreshToken(
            transactions: refreshVersion(for: .transactions),
            accounts: refreshVersion(for: .accounts),
            budgets: refreshVersion(for: .budgets),
            recurring: refreshVersion(for: .recurring)
        )
    }

    func notifyChanged(_ domain: DataRefreshDomain) {
        refreshVersions[domain, default: 0] &+= 1
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
