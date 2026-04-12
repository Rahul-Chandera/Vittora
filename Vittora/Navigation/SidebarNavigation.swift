import SwiftUI

struct SidebarNavigation: View {
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(selection: $appState.selectedTab) {
                Section("Overview") {
                    Label(AppState.AppTab.dashboard.title,
                          systemImage: AppState.AppTab.dashboard.systemImage)
                        .tag(AppState.AppTab.dashboard)
                }

                Section("Money") {
                    Label(AppState.AppTab.transactions.title,
                          systemImage: AppState.AppTab.transactions.systemImage)
                        .tag(AppState.AppTab.transactions)
                    Label(AppState.AppTab.budgets.title,
                          systemImage: AppState.AppTab.budgets.systemImage)
                        .tag(AppState.AppTab.budgets)
                }

                Section("Insights") {
                    Label(AppState.AppTab.reports.title,
                          systemImage: AppState.AppTab.reports.systemImage)
                        .tag(AppState.AppTab.reports)
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
        } detail: {
            NavigationStack {
                Group {
                    switch appState.selectedTab {
                    case .dashboard: PlaceholderView(tab: .dashboard)
                    case .transactions: PlaceholderView(tab: .transactions)
                    case .budgets: PlaceholderView(tab: .budgets)
                    case .reports: PlaceholderView(tab: .reports)
                    case .settings: PlaceholderView(tab: .settings)
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
            #else
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label(String(localized: "New Transaction"), systemImage: "plus")
                }
            }
            #endif
        }
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                Text(String(localized: "Add Transaction"))
                    .navigationTitle(String(localized: "New Transaction"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Cancel")) {
                                showAddTransaction = false
                            }
                        }
                    }
            }
        }
    }
}
