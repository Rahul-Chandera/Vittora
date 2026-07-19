import SwiftUI
import VittoraCore

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        ZStack {
            if !appState.isUITesting || appState.exercisesAppLockPolicy,
                settingsVM.isAppLockEnabled,
                (appState.isLocked || !appState.isAuthenticated) {
                AppLockView()
            } else {
                if !appState.isOnboardingComplete {
                    OnboardingView(
                        createAccountUseCase: CreateAccountUseCase(
                            accountRepository: dependencies.accountRepository
                        )
                    )
                } else {
                    #if os(macOS)
                    SidebarNavigation()
                    #else
                    AppTabView()
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
        #if os(iOS)
        .onAppear {
            KeyboardDismissGesture.installIfNeeded()
        }
        #endif
        .onAppear {
            mirrorAppLockSession()
        }
        .onChange(of: settingsVM.isAppLockEnabled) { _, _ in
            mirrorAppLockSession()
        }
        .onChange(of: settingsVM.appLockTimeout) { _, _ in
            mirrorAppLockSession()
        }
        .onChange(of: appState.isLocked) { _, _ in
            mirrorAppLockSession()
        }
        .onChange(of: appState.isAuthenticated) { _, _ in
            mirrorAppLockSession()
        }
        .onChange(of: appState.isOnboardingComplete) { _, isComplete in
            // Onboarding writes the name/currency straight to storage; refresh the
            // shared view model so the main app shows them without a restart.
            if isComplete {
                settingsVM.reloadPersistedProfile()
            }
        }
    }

    private func mirrorAppLockSession() {
        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: settingsVM.isAppLockEnabled,
            isLocked: appState.isLocked,
            isAuthenticated: appState.isAuthenticated,
            timeout: settingsVM.appLockTimeout.timeInterval
        )
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
        // Deliberately NOT .privacySensitive(): this overlay IS the privacy
        // cover. Marking it sensitive made the system redact its own icon and
        // label into a box + bar during Face ID auth (scene inactive).
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
