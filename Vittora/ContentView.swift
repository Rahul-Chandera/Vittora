import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.dependencies) private var dependencies
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        ZStack {
            if !appState.isUITesting && settingsVM.isAppLockEnabled && appState.isLocked {
                AppLockView()
            } else {
                if !appState.isOnboardingComplete {
                    OnboardingView(
                        createAccountUseCase: dependencies.accountRepository.map {
                            CreateAccountUseCase(accountRepository: $0)
                        }
                    )
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
        .accessibilityIdentifier("content-root")
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(Router())
        .environment(SettingsViewModel())
        .environment(SyncStatusService())
}
