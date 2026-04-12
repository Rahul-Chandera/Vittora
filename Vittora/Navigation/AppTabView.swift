import SwiftUI

struct AppTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                Tab(AppState.AppTab.dashboard.title,
                    systemImage: AppState.AppTab.dashboard.systemImage,
                    value: .dashboard) {
                    NavigationStack {
                        PlaceholderView(tab: .dashboard)
                            .withNavigationDestinations()
                    }
                }

                Tab(AppState.AppTab.transactions.title,
                    systemImage: AppState.AppTab.transactions.systemImage,
                    value: .transactions) {
                    NavigationStack {
                        PlaceholderView(tab: .transactions)
                            .withNavigationDestinations()
                    }
                }

                Tab(AppState.AppTab.budgets.title,
                    systemImage: AppState.AppTab.budgets.systemImage,
                    value: .budgets) {
                    NavigationStack {
                        PlaceholderView(tab: .budgets)
                            .withNavigationDestinations()
                    }
                }

                Tab(AppState.AppTab.reports.title,
                    systemImage: AppState.AppTab.reports.systemImage,
                    value: .reports) {
                    NavigationStack {
                        PlaceholderView(tab: .reports)
                            .withNavigationDestinations()
                    }
                }

                Tab(AppState.AppTab.settings.title,
                    systemImage: AppState.AppTab.settings.systemImage,
                    value: .settings) {
                    NavigationStack {
                        PlaceholderView(tab: .settings)
                            .withNavigationDestinations()
                    }
                }
            }

            QuickEntryButton {
                showAddTransaction = true
            }
            .padding(.bottom, 60)
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
