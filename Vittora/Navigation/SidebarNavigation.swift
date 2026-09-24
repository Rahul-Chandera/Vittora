import SwiftUI
import VittoraCore

#if os(macOS)
struct SidebarNavigation: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentedQuickAdd: PresentedQuickAdd?

    /// Which way the detail pane slides on the next change.
    ///
    /// iOS-style push/pop, requested for parity with the phone app. Note this
    /// is deliberately NOT the macOS idiom — Mail, Notes and Finder swap
    /// sidebar content instantly — so it is kept short and is skipped entirely
    /// under Reduce Motion.
    @State private var isMovingDown = true

    private func select(_ tab: AppState.AppTab) {
        guard tab != appState.selectedTab else { return }
        isMovingDown = SidebarOrder.movesDown(from: appState.selectedTab, to: tab)
        if reduceMotion {
            appState.selectedTab = tab
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                appState.selectedTab = tab
            }
        }
    }

    private func sidebarRow(_ tab: AppState.AppTab) -> some View {
        let isSelected = appState.selectedTab == tab
        let accent = VColors.accent(settingsVM.accentColor)
        let onAccent = VColors.onAccent(for: settingsVM.accentColor)
        return Button {
            select(tab)
        } label: {
            // Split label: the icon keeps the accent when the row is not selected,
            // which is how AppKit drew it, and both flip to onAccent when it is.
            Label {
                Text(tab.title)
                    .foregroundStyle(isSelected ? onAccent : VColors.textPrimary)
            } icon: {
                Image(systemName: tab.systemImage)
                    .foregroundStyle(isSelected ? onAccent : accent)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, VSpacing.xs)
                .padding(.horizontal, VSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? accent : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        // .plain, or AppKit gives every row a bordered button of its own.
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// iOS push/pop: the arriving screen comes from the trailing edge and the
    /// leaving one exits to the leading edge, reversed when moving back up the
    /// sidebar. `.identity` under Reduce Motion so the swap is instant.
    private var pushTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        let incoming: Edge = isMovingDown ? .trailing : .leading
        let outgoing: Edge = isMovingDown ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming).combined(with: .opacity),
            removal: .move(edge: outgoing).combined(with: .opacity)
        )
    }

    var body: some View {
        NavigationSplitView {
            // Rows are buttons, not List selection. AppKit paints the source-list
            // highlight with NSColor.controlAccentColor — the System Settings accent,
            // which is why this sidebar stayed blue while the rest of the app followed
            // the in-app accent. SwiftUI's .tint does not reach it, on the List or
            // above it. Drawing the highlight ourselves is the only way it follows the
            // user's choice, and it is what the iOS tab bar already does.
            List {
                Section(String(localized: "Overview")) {
                    sidebarRow(.dashboard)
                }

                Section(String(localized: "Money")) {
                    sidebarRow(.transactions)
                    sidebarRow(.budgets)
                    sidebarRow(.savings)
                }

                Section(String(localized: "Insights")) {
                    sidebarRow(.reports)
                    sidebarRow(.tax)
                }

                Section(String(localized: "Social")) {
                    sidebarRow(.debt)
                    sidebarRow(.splits)
                }

                Section {
                    sidebarRow(.settings)
                }
            }
            .navigationTitle("Vittora")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
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
                // `.id` is what makes this a transition at all: without it
                // SwiftUI updates the existing view in place and there is
                // nothing to move in or out.
                .id(appState.selectedTab)
                .transition(pushTransition)
                .withNavigationDestinations()
            }
        }
        // No window-global "+" here: it stacks with each screen's own add
        // button (Categories, Budgets, …) so every pushed screen showed two.
        // Quick entry stays reachable via ⌘N and the dashboard floating +.
        .toolbar {
            ToolbarItem(placement: .status) {
                SyncStatusView()
            }
        }
        .quickAddPresentation($presentedQuickAdd, asSheet: true)
        .handlesAppCommands(
            appState: appState,
            presentedQuickAdd: $presentedQuickAdd
        )
    }
}
#endif
