import SwiftUI
import VittoraCore

#if os(iOS)
struct AppTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var presentedQuickAdd: PresentedQuickAdd?

    /// Tabs kept on the compact iPhone bar. Everything else lives in the "More"
    /// hub so we never overflow into the system "More" tab, which nests a second
    /// navigation controller and produces a duplicate back button.
    private static let primaryCompactTabs: Set<AppState.AppTab> =
        [.dashboard, .transactions, .budgets, .reports]

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactTabView
            } else {
                regularTabView
            }
        }
        // Match the dashboard quick actions: a centered sheet on regular width
        // (iPad), full-screen cover only on compact (iPhone).
        .quickAddPresentation(
            $presentedQuickAdd,
            asSheet: horizontalSizeClass == .regular
        )
        .handlesAppCommands(appState: appState, presentedQuickAdd: $presentedQuickAdd)
    }

    // MARK: - Regular width (iPad / macOS Catalyst): full sectioned sidebar

    private var regularTabView: some View {
        @Bindable var appState = appState

        return TabView(selection: $appState.selectedTab) {
            TabSection {
                Tab(AppState.AppTab.dashboard.title,
                    systemImage: AppState.AppTab.dashboard.systemImage,
                    value: AppState.AppTab.dashboard) {
                    NavigationStack {
                        DashboardView()
                            .withNavigationDestinations()
                    }
                }
            } header: {
                Text(String(localized: "Overview"))
            }

            TabSection {
                Tab(AppState.AppTab.transactions.title,
                    systemImage: AppState.AppTab.transactions.systemImage,
                    value: AppState.AppTab.transactions) {
                    NavigationStack {
                        TransactionListView()
                            .withNavigationDestinations()
                    }
                }
                Tab(AppState.AppTab.budgets.title,
                    systemImage: AppState.AppTab.budgets.systemImage,
                    value: AppState.AppTab.budgets) {
                    NavigationStack {
                        BudgetListView()
                            .withNavigationDestinations()
                    }
                }
                Tab(AppState.AppTab.savings.title,
                    systemImage: AppState.AppTab.savings.systemImage,
                    value: AppState.AppTab.savings) {
                    NavigationStack {
                        SavingsGoalListView()
                            .withNavigationDestinations()
                    }
                }
            } header: {
                Text(String(localized: "Money"))
            }

            TabSection {
                Tab(AppState.AppTab.reports.title,
                    systemImage: AppState.AppTab.reports.systemImage,
                    value: AppState.AppTab.reports) {
                    NavigationStack {
                        ReportsHomeView()
                            .withNavigationDestinations()
                    }
                }
                Tab(AppState.AppTab.tax.title,
                    systemImage: AppState.AppTab.tax.systemImage,
                    value: AppState.AppTab.tax) {
                    NavigationStack {
                        TaxDashboardView()
                            .withNavigationDestinations()
                    }
                }
            } header: {
                Text(String(localized: "Insights"))
            }

            TabSection {
                Tab(AppState.AppTab.debt.title,
                    systemImage: AppState.AppTab.debt.systemImage,
                    value: AppState.AppTab.debt) {
                    NavigationStack {
                        DebtLedgerView()
                            .withNavigationDestinations()
                    }
                }
                Tab(AppState.AppTab.splits.title,
                    systemImage: AppState.AppTab.splits.systemImage,
                    value: AppState.AppTab.splits) {
                    NavigationStack {
                        SplitGroupListView()
                            .withNavigationDestinations()
                    }
                }
            } header: {
                Text(String(localized: "Social"))
            }

            // The header is load-bearing: the sidebarAdaptable style renders a
            // header-less TabSection as an empty disclosure (no row, no
            // top-bar item), leaving Settings unreachable on iPad. A bare Tab
            // works but floats to the top of the sidebar, out of order.
            TabSection {
                Tab(AppState.AppTab.settings.title,
                    systemImage: AppState.AppTab.settings.systemImage,
                    value: AppState.AppTab.settings) {
                    NavigationStack {
                        SettingsView()
                            .withNavigationDestinations()
                    }
                }
            } header: {
                Text(String(localized: "General"))
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    // MARK: - Compact width (iPhone): 4 primary tabs + a self-owned More hub

    private var compactTabView: some View {
        TabView(selection: compactSelection) {
            Tab(AppState.AppTab.dashboard.title,
                systemImage: AppState.AppTab.dashboard.systemImage,
                value: AppState.AppTab.dashboard) {
                NavigationStack {
                    DashboardView()
                        .withNavigationDestinations()
                }
            }
            Tab(AppState.AppTab.transactions.title,
                systemImage: AppState.AppTab.transactions.systemImage,
                value: AppState.AppTab.transactions) {
                NavigationStack {
                    TransactionListView()
                        .withNavigationDestinations()
                }
            }
            Tab(AppState.AppTab.budgets.title,
                systemImage: AppState.AppTab.budgets.systemImage,
                value: AppState.AppTab.budgets) {
                NavigationStack {
                    BudgetListView()
                        .withNavigationDestinations()
                }
            }
            Tab(AppState.AppTab.reports.title,
                systemImage: AppState.AppTab.reports.systemImage,
                value: AppState.AppTab.reports) {
                NavigationStack {
                    ReportsHomeView()
                        .withNavigationDestinations()
                }
            }
            Tab(String(localized: "More"),
                systemImage: "ellipsis",
                value: AppState.AppTab.settings) {
                NavigationStack {
                    MoreHubView()
                        .withNavigationDestinations()
                }
            }
        }
        // System blue for the selected tab, not .primary — a monochrome selection
        // gives no signal about which tab is active. Deliberately independent of the
        // user's accent theme: the accent doubles as a fill colour and is too light
        // (brandGreen #3FCFA4) to read as a selected glyph on the tab bar.
        .tint(.blue)
        .toolbarBackground(VColors.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    /// Selection for the compact bar. Deep-links to overflow destinations
    /// (debt/splits/savings/tax/settings) resolve to the More tab rather than a
    /// non-existent tab, so the bar never lands on a blank selection.
    /// ponytail: overflow deep-links land on the More hub root, not the exact
    /// screen; add per-destination routing only if that shortcut matters.
    private var compactSelection: Binding<AppState.AppTab> {
        Binding(
            get: {
                Self.primaryCompactTabs.contains(appState.selectedTab)
                    ? appState.selectedTab
                    : .settings
            },
            set: { appState.selectedTab = $0 }
        )
    }
}

// MARK: - More hub

/// Single-NavigationStack list of the destinations that don't fit the compact
/// tab bar. One nav bar → one back button on every screen reached from here.
private struct MoreHubView: View {
    private static let destinations: [AppState.AppTab] =
        [.savings, .tax, .debt, .splits, .settings]

    /// Icon hue per destination. Decorative — the row's label carries the meaning.
    private static func tint(for tab: AppState.AppTab) -> VColors.IconTint {
        switch tab {
        case .savings:  return .green
        case .tax:      return .teal
        case .debt:     return .orange
        case .splits:   return .purple
        case .settings: return .blue
        default:        return .blue
        }
    }

    var body: some View {
        List {
            ForEach(Self.destinations) { tab in
                NavigationLink {
                    destinationView(for: tab)
                } label: {
                    Label {
                        Text(tab.title)
                    } icon: {
                        Image(systemName: tab.systemImage)
                            .foregroundStyle(VColors.iconTint(Self.tint(for: tab)))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "More"))
    }

    @ViewBuilder
    private func destinationView(for tab: AppState.AppTab) -> some View {
        switch tab {
        case .savings:  SavingsGoalListView()
        case .tax:      TaxDashboardView()
        case .debt:     DebtLedgerView()
        case .splits:   SplitGroupListView()
        case .settings: SettingsView()
        default:        EmptyView()
        }
    }
}
#endif
