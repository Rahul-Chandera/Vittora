import SwiftUI

@Observable
@MainActor
final class AppState {
    var isAuthenticated: Bool = false
    var isOnboardingComplete: Bool = false
    var selectedTab: AppTab = .dashboard
    var isLoading: Bool = false

    enum AppTab: String, CaseIterable, Identifiable, Sendable {
        case dashboard
        case transactions
        case budgets
        case reports
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: String(localized: "Dashboard")
            case .transactions: String(localized: "Transactions")
            case .budgets: String(localized: "Budgets")
            case .reports: String(localized: "Reports")
            case .settings: String(localized: "Settings")
            }
        }

        var systemImage: String {
            switch self {
            case .dashboard: "chart.pie.fill"
            case .transactions: "list.bullet.rectangle.fill"
            case .budgets: "target"
            case .reports: "chart.bar.fill"
            case .settings: "gearshape.fill"
            }
        }
    }
}
