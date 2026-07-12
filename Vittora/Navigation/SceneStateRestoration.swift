import SwiftUI
import VittoraCore

extension View {
    /// Persists selected tab via `@SceneStorage` and publishes Handoff user activity.
    func restoresSceneState(appState: AppState) -> some View {
        modifier(SceneStateRestorationModifier(appState: appState))
    }
}

private struct SceneStateRestorationModifier: ViewModifier {
    @Bindable var appState: AppState
    @SceneStorage("vittora.selectedTab") private var storedTabRaw: String?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: restoreSelectedTabIfNeeded)
            .onChange(of: appState.selectedTab) { _, tab in
                guard !appState.isUITesting else { return }
                storedTabRaw = tab.rawValue
            }
            .userActivity(AppHandoff.activityType, isActive: !appState.isUITesting) { activity in
                activity.title = String(localized: "Vittora")
                activity.isEligibleForHandoff = true
                activity.userInfo = [AppHandoff.tabKey: appState.selectedTab.rawValue]
                activity.requiredUserInfoKeys = Set([AppHandoff.tabKey])
            }
            .onContinueUserActivity(AppHandoff.activityType) { activity in
                guard let raw = activity.userInfo?[AppHandoff.tabKey] as? String,
                      let tab = AppState.AppTab(rawValue: raw) else { return }
                appState.selectedTab = tab
            }
    }

    private func restoreSelectedTabIfNeeded() {
        guard !appState.isUITesting,
              let raw = storedTabRaw,
              let tab = AppState.AppTab(rawValue: raw) else { return }
        appState.selectedTab = tab
    }
}
