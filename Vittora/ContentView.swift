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
            if !appState.isUITesting &&
                settingsVM.isAppLockEnabled &&
                (appState.isLocked || !appState.isAuthenticated) {
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

            if appState.isPrivacyShieldVisible {
                PrivacyShieldOverlay()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .accessibilityIdentifier("content-root")
    }
}

private struct PrivacyShieldOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: VSpacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(VColors.primary)
                    .accessibilityHidden(true)

                Text(String(localized: "Private data hidden"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)
            }
        }
        .privacySensitive()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Private financial data is hidden"))
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(SyncStatusService())
}
