import SwiftUI
import VittoraCore

#if os(iOS)
struct AppTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
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

            TabSection {
                Tab(AppState.AppTab.settings.title,
                    systemImage: AppState.AppTab.settings.systemImage,
                    value: AppState.AppTab.settings) {
                    NavigationStack {
                        SettingsView()
                            .withNavigationDestinations()
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .fullScreenCover(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView()
            }
        }
        .handlesAppCommands(appState: appState, showAddTransaction: $showAddTransaction)
    }
}
#endif
