import SwiftUI

struct SidebarNavigation: View {
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var showAddTransaction = false
    @State private var selectedTab: AppState.AppTab? = .dashboard

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(selection: $selectedTab) {
                Section(String(localized: "Overview")) {
                    Label(AppState.AppTab.dashboard.title,
                          systemImage: AppState.AppTab.dashboard.systemImage)
                        .tag(AppState.AppTab.dashboard)
                }

                Section(String(localized: "Money")) {
                    Label(AppState.AppTab.transactions.title,
                          systemImage: AppState.AppTab.transactions.systemImage)
                        .tag(AppState.AppTab.transactions)
                    Label(AppState.AppTab.budgets.title,
                          systemImage: AppState.AppTab.budgets.systemImage)
                        .tag(AppState.AppTab.budgets)
                    Label(AppState.AppTab.savings.title,
                          systemImage: AppState.AppTab.savings.systemImage)
                        .tag(AppState.AppTab.savings)
                }

                Section(String(localized: "Insights")) {
                    Label(AppState.AppTab.reports.title,
                          systemImage: AppState.AppTab.reports.systemImage)
                        .tag(AppState.AppTab.reports)
                    Label(AppState.AppTab.tax.title,
                          systemImage: AppState.AppTab.tax.systemImage)
                        .tag(AppState.AppTab.tax)
                }

                Section(String(localized: "Social")) {
                    Label(AppState.AppTab.debt.title,
                          systemImage: AppState.AppTab.debt.systemImage)
                        .tag(AppState.AppTab.debt)
                    Label(AppState.AppTab.splits.title,
                          systemImage: AppState.AppTab.splits.systemImage)
                        .tag(AppState.AppTab.splits)
                }

                Section {
                    Label(AppState.AppTab.settings.title,
                          systemImage: AppState.AppTab.settings.systemImage)
                        .tag(AppState.AppTab.settings)
                }
            }
            .navigationTitle("Vittora")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            #endif
            .onChange(of: selectedTab) { _, newValue in
                if let tab = newValue { appState.selectedTab = tab }
            }
            .onChange(of: appState.selectedTab) { _, newValue in
                selectedTab = newValue
            }
        } detail: {
            NavigationStack {
                Group {
                    switch appState.selectedTab {
                    case .dashboard:    DashboardView()
                    case .transactions: TransactionListView()
                    case .budgets:      BudgetListView()
                    case .reports:      ReportsHomeView()
                    case .debt:         DebtLedgerView()
                    case .splits:       SplitGroupListView()
                    case .tax:          TaxDashboardView()
                    case .savings:      SavingsGoalListView()
                    case .settings:     SettingsView()
                    }
                }
                .withNavigationDestinations()
            }
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label(String(localized: "New Transaction"), systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .status) {
                SyncStatusView()
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label(String(localized: "New Transaction"), systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                SyncStatusView()
            }
            #endif
        }
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                TransactionFormView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vittoraNewTransaction)) { _ in
            showAddTransaction = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .vittoraOpenSettings)) { _ in
            appState.selectedTab = .settings
        }
    }
}
