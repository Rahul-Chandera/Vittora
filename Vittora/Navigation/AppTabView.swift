import SwiftUI
import VittoraCore

#if os(iOS)
struct AppTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var presentedQuickAdd: PresentedQuickAdd?

    var body: some View {
        rootTabView
            .quickAddPresentation($presentedQuickAdd)
            .handlesAppCommands(appState: appState, presentedQuickAdd: $presentedQuickAdd)
    }

    // MARK: - One TabView for every width

    /// One adaptive TabView: a sidebar on regular width, a tab bar on compact.
    ///
    /// It used to be two TabViews chosen by size class. On iPhone Duo the size
    /// class flips every time the device folds or unfolds, and swapping
    /// TabViews threw away every tab's navigation stack mid-session. One
    /// TabView keeps each tab's content, and only the chrome adapts.
    ///
    /// The compact bar still shows four primary tabs plus our own More hub, so
    /// we never overflow into the system "More" tab (which nests a second
    /// navigation controller and draws a duplicate back button). The overflow
    /// tabs are left out on compact rather than hidden: on iPhone, including the
    /// iPhone Duo's vertical bar, `defaultVisibility(.hidden, for: .tabBar)` is
    /// ignored (it applies to the iPad tab bar only), which dropped Reports and
    /// overflowed into the system More list. The four primary tabs are always
    /// declared, so their identity, and their navigation, survives a fold.
    private var rootTabView: some View {
        TabView(selection: selection) {
            TabSection {
                tab(.dashboard) { DashboardView() }
            } header: {
                Text(String(localized: "Overview"))
            }

            TabSection {
                tab(.transactions) { TransactionListView() }
                tab(.budgets) { BudgetListView() }
                if !isCompact {
                    tab(.savings) { SavingsGoalListView() }
                }
            } header: {
                Text(String(localized: "Money"))
            }

            TabSection {
                tab(.reports) { ReportsHomeView() }
                if !isCompact {
                    tab(.tax) { TaxDashboardView() }
                }
            } header: {
                Text(String(localized: "Insights"))
            }

            if isCompact {
                Tab(String(localized: "More"), systemImage: "ellipsis", value: RootTab.more) {
                    contentStack {
                        MoreHubView()
                            .withNavigationDestinations()
                    }
                }
            } else {
                TabSection {
                    tab(.debt) { DebtLedgerView() }
                    tab(.splits) { SplitGroupListView() }
                } header: {
                    Text(String(localized: "Social"))
                }

                // The header is load-bearing: the sidebarAdaptable style renders a
                // header-less TabSection as an empty disclosure (no row, no
                // top-bar item), leaving Settings unreachable on iPad. A bare Tab
                // works but floats to the top of the sidebar, out of order.
                TabSection {
                    tab(.settings) { SettingsView() }
                } header: {
                    Text(String(localized: "General"))
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Compact only, as before: the selected tab matches the accent swatch the
        // user picked (DEC-012), on an opaque grouped-background bar. Tab labels
        // are excluded from the contrast audit — XCTest samples the liquid-glass
        // highlight rather than the bar material. Values, not conditional
        // modifiers, so a fold never changes the view's identity.
        .tint(isCompact ? VColors.primary : nil)
        .toolbarBackground(VColors.groupedBackground, for: .tabBar)
        .toolbarBackground(isCompact ? .visible : .automatic, for: .tabBar)
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }

    /// A tab for `appTab` whose root is `content`, in its own navigation stack.
    private func tab<Content: View>(
        _ appTab: AppState.AppTab,
        @ViewBuilder content: () -> Content
    ) -> some TabContent<RootTab> {
        Tab(appTab.title, systemImage: appTab.systemImage, value: RootTab.tab(appTab)) {
            contentStack {
                content()
                    .withNavigationDestinations()
            }
        }
    }

    /// A tab's root stack, tinted for content.
    ///
    /// The tint has to sit on the NavigationStack, not on the view inside it.
    /// Pushed destinations are rendered by the stack and inherit ITS
    /// environment, so a tint applied to the content — which is what the first
    /// version of this fix did — reached the tab's root screen but never the
    /// screens pushed from it. CI caught the gap on Monthly Overview, whose
    /// year Picker was still drawing in the accent FILL colour: purple on the
    /// dark card measures 3.35:1, under the 4.5:1 body-text minimum.
    ///
    /// The TabView keeps its own `.tint(VColors.primary)` so the selected tab
    /// still matches the accent swatch the user picked.
    @ViewBuilder
    private func contentStack<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .tint(VColors.primaryOnSurface)
    }

    /// The TabView's selection. The More hub is a value of its own so it can sit
    /// beside the Settings tab in one TabView.
    ///
    /// Since the iOS 27 SDK a TabView may crash when its selection names a tab
    /// that is hidden, so this never returns one: on compact, overflow tabs
    /// (savings, tax, debt, splits, settings) resolve to the More hub, as deep
    /// links always have; on regular, every tab is visible and the hub is not.
    private var selection: Binding<RootTab> {
        Binding(
            get: {
                guard isCompact else { return .tab(appState.selectedTab) }
                let tab = AppState.AppTab.compactTabBarSelection(for: appState.selectedTab)
                return tab == .settings ? .more : .tab(tab)
            },
            set: { root in
                switch root {
                case .tab(let tab): appState.selectedTab = tab
                // The hub stands for Settings and the overflow destinations, so
                // unfolding from it lands on Settings, its nearest regular-width tab.
                case .more: appState.selectedTab = .settings
                }
            }
        )
    }
}

private enum RootTab: Hashable {
    case tab(AppState.AppTab)
    case more
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

    @State private var showShoppingMode = false

    var body: some View {
        List {
            Group {
                // Its own section rather than an AppTab case: shopping mode is a
                // transient session, not a destination, and adding a tab would ripple
                // through deep links, the sidebar and compact-bar routing for nothing.
                #if os(iOS)
                Section {
                    Button {
                        showShoppingMode = true
                    } label: {
                        Label {
                            Text(String(localized: "Shopping Mode"))
                                .foregroundStyle(VColors.textPrimary)
                        } icon: {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(VColors.iconTint(.green))
                        }
                    }
                    .accessibilityIdentifier("more-shopping-mode-row")
                }
                #endif

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
                    // Locale-independent handle for UI tests and store captures.
                    .accessibilityIdentifier("more-\(tab.rawValue)-row")
                }
            }
            .vListContentTint()
        }
        .vListSelectionTint()
        .navigationTitle(String(localized: "More"))
        #if os(iOS)
        .sheet(isPresented: $showShoppingMode) {
            ShoppingModeView()
        }
        #endif
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
