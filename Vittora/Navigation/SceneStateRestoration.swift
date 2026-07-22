import SwiftUI
import VittoraCore

extension View {
    /// Persists selected tab via `@SceneStorage` and continues Handoff activities
    /// through the existing deep-link routing path.
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
            .onContinueUserActivity(AppHandoff.transactionsType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.transactionType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.budgetType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.reportType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.accountType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.transactionDraftType, perform: continueHandoff)
            .onContinueUserActivity(AppHandoff.mainType, perform: continueHandoff)
    }

    private func continueHandoff(_ activity: NSUserActivity) {
        appState.openFromHandoffActivity(activity)
    }

    private func restoreSelectedTabIfNeeded() {
        guard !appState.isUITesting,
              let raw = storedTabRaw,
              let tab = AppState.AppTab(rawValue: raw) else { return }
        appState.selectedTab = tab
    }
}
