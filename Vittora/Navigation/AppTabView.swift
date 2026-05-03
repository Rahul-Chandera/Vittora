import SwiftUI

struct AppTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
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

            Tab(AppState.AppTab.debt.title,
                systemImage: AppState.AppTab.debt.systemImage,
                value: AppState.AppTab.debt) {
                DebtLedgerView()
            }

            Tab(AppState.AppTab.splits.title,
                systemImage: AppState.AppTab.splits.systemImage,
                value: AppState.AppTab.splits) {
                SplitGroupListView()
            }

            Tab(AppState.AppTab.tax.title,
                systemImage: AppState.AppTab.tax.systemImage,
                value: AppState.AppTab.tax) {
                TaxDashboardView()
            }

            Tab(AppState.AppTab.savings.title,
                systemImage: AppState.AppTab.savings.systemImage,
                value: AppState.AppTab.savings) {
                SavingsGoalListView()
            }

            Tab(AppState.AppTab.settings.title,
                systemImage: AppState.AppTab.settings.systemImage,
                value: AppState.AppTab.settings) {
                NavigationStack {
                    SettingsView()
                        .withNavigationDestinations()
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView()
            }
        }
        #else
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView()
            }
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .vittoraNewTransaction)) { _ in
            showAddTransaction = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .vittoraOpenSettings)) { _ in
            appState.selectedTab = .settings
        }
    }
}
