import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsVM
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        if settingsVM.isAppLockEnabled && appState.isLocked {
            AppLockView()
        } else if !appState.isOnboardingComplete {
            OnboardingView()
        } else {
            #if os(macOS)
            SidebarNavigation()
            #else
            if horizontalSizeClass == .regular {
                SidebarNavigation() // iPad
            } else {
                AppTabView()        // iPhone
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(Router())
        .environment(SettingsViewModel())
}
