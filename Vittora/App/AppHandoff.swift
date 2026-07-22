import Foundation
import VittoraCore

/// Handoff / Continuity activity types and encode → decode helpers.
///
/// Continuation always feeds `AppState.openFromURL` via `HandoffDeepLink.url(for:)`.
/// Spotlight indexing stays in `TransactionSpotlightIndex` — these activities set
/// `eligibleForSearch = false` so they do not double-index.
nonisolated enum AppHandoff {
    static let transactionsType = "com.enerjiktech.vittora.transactions"
    static let transactionType = "com.enerjiktech.vittora.transaction"
    static let budgetType = "com.enerjiktech.vittora.budget"
    static let reportType = "com.enerjiktech.vittora.report"
    static let accountType = "com.enerjiktech.vittora.account"
    static let transactionDraftType = "com.enerjiktech.vittora.transactionDraft"

    /// Legacy tab-only activity (scene restore). Still declared for devices that
    /// may have advertised it; continuation maps to the matching tab only.
    static let mainType = "com.enerjiktech.vittora.main"
    static let tabKey = "selectedTab"

    static let allContinuableTypes: [String] = [
        transactionsType,
        transactionType,
        budgetType,
        reportType,
        accountType,
        transactionDraftType,
        mainType,
    ]

    static func activityType(for route: HandoffDeepLink.Route) -> String {
        switch route {
        case .transactionList: transactionsType
        case .transactionDetail: transactionType
        case .budgetsList, .budgetDetail: budgetType
        case .accountsList, .accountDetail: accountType
        case .reportDetail: reportType
        case .transactionDraft: transactionDraftType
        }
    }

    static func title(for route: HandoffDeepLink.Route) -> String {
        switch route {
        case .transactionList:
            String(localized: "Transactions")
        case .transactionDetail:
            String(localized: "Transaction")
        case .budgetsList, .budgetDetail:
            String(localized: "Budget")
        case .accountsList, .accountDetail:
            String(localized: "Account")
        case .reportDetail:
            String(localized: "Report")
        case .transactionDraft:
            String(localized: "New Transaction")
        }
    }

    /// Builds a Continuity activity for the given route (identifiers / draft only).
    static func makeActivity(for route: HandoffDeepLink.Route) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityType(for: route))
        configure(activity, route: route)
        return activity
    }

    static func configure(_ activity: NSUserActivity, route: HandoffDeepLink.Route) {
        activity.title = title(for: route)
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        // userInfo must be a property-list dictionary (identifiers / draft fields only).
        let info = HandoffDeepLink.userInfo(for: route)
        activity.userInfo = info
        activity.requiredUserInfoKeys = HandoffDeepLink.requiredUserInfoKeys(for: route)
        // ponytail: skip webpageURL — custom vittora:// URLs are not Universal Links
        // and have crashed NSUserActivity configuration in the simulator test host.
    }

    static func route(from activity: NSUserActivity) -> HandoffDeepLink.Route? {
        if activity.activityType == mainType {
            return nil
        }
        if let route = HandoffDeepLink.route(fromUserInfo: activity.userInfo) {
            return route
        }
        if let url = activity.webpageURL {
            return HandoffDeepLink.route(from: url)
        }
        return nil
    }
}
