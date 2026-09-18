import Foundation
import Testing
@testable import Vittora

/// The compact tab bar declares five of AppTab's nine values. Since the iOS 27 SDK a
/// TabView "might crash when its selection is set to a hidden or otherwise unavailable
/// tab" (iOS 27 release notes, 164516837), so clamping an arbitrary tab to one the bar
/// actually owns stopped being cosmetic and became crash prevention.
///
/// Deep links, Handoff, Spotlight results and app commands all write `selectedTab`
/// directly, and any of them can name an overflow destination.
@Suite("Compact Tab Selection Tests")
struct CompactTabSelectionTests {
    /// Catches a regression where the clamp is dropped or narrowed, which would hand the
    /// compact TabView a value it does not declare.
    @Test("every AppTab clamps to a tab the compact bar declares", arguments: AppState.AppTab.allCases)
    func everyTabClampsToADeclaredTab(_ tab: AppState.AppTab) {
        let selection = AppState.AppTab.compactTabBarSelection(for: tab)
        #expect(AppState.AppTab.compactTabBarTabs.contains(selection))
    }

    /// The four primary tabs must pass through untouched — clamping them would silently
    /// redirect a correct deep link to the More hub.
    @Test("a tab the compact bar declares is returned unchanged",
          arguments: [AppState.AppTab.dashboard, .transactions, .budgets, .reports, .settings])
    func declaredTabsPassThrough(_ tab: AppState.AppTab) {
        #expect(AppState.AppTab.compactTabBarSelection(for: tab) == tab)
    }

    /// The overflow destinations live behind the More hub, which is the `.settings` tab.
    @Test("overflow destinations land on the More hub",
          arguments: [AppState.AppTab.savings, .tax, .debt, .splits])
    func overflowTabsLandOnMoreHub(_ tab: AppState.AppTab) {
        #expect(AppState.AppTab.compactTabBarSelection(for: tab) == .settings)
    }

    /// Pins the two sets against each other. If a tab is added to AppTab and to the compact
    /// bar's declarations but not to `compactTabBarTabs`, the clamp would send a perfectly
    /// valid selection to the More hub instead; if it is added here but not to the bar, the
    /// clamp would hand TabView a value it does not own, which is the crash.
    @Test("the declared set is a subset of all tabs, and names the More hub")
    func declaredSetIsConsistent() {
        #expect(AppState.AppTab.compactTabBarTabs.isSubset(of: Set(AppState.AppTab.allCases)))
        #expect(AppState.AppTab.compactTabBarTabs.contains(.settings))
    }
}
