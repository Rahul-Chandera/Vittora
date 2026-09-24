import Foundation

/// The sidebar's visual order, and which way the detail pane should slide.
///
/// Deliberately NOT inside `#if os(macOS)`, even though only the macOS sidebar
/// uses it. CI runs the test suite on the iOS Simulator only, so anything
/// behind a macOS condition is never executed by a gate — the ordering would
/// be the kind of quietly-wrong detail that ships. Kept platform-agnostic so
/// it is covered on every run.
nonisolated enum SidebarOrder {
    /// The order the rows appear in, which is NOT `AppTab`'s declaration order:
    /// the enum has reports/debt/splits before tax/savings, while the sidebar
    /// shows savings before reports. Direction has to follow what the user
    /// sees, or Savings -> Reports animates backwards.
    nonisolated static let tabs: [AppState.AppTab] = [
        .dashboard,
        .transactions, .budgets, .savings,
        .reports, .tax,
        .debt, .splits,
        .settings,
    ]

    /// True when `to` sits below `from` in the sidebar — a forward push.
    nonisolated static func movesDown(from: AppState.AppTab, to: AppState.AppTab) -> Bool {
        let fromIndex = tabs.firstIndex(of: from) ?? 0
        let toIndex = tabs.firstIndex(of: to) ?? 0
        return toIndex >= fromIndex
    }
}
