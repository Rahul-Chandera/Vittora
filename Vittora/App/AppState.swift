import SwiftUI

@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool = false
    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "vittora.onboardingComplete")
    var selectedTab: AppTab = .dashboard
    var isLoading: Bool = false

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

        var id: String { rawValue }

        var title: String {
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

        var systemImage: String {
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
