import SwiftUI
import VittoraCore

struct AppLockView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.dependencies) private var dependencies

    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var cooldownRemaining: Int = 0

    private var isLockServiceAvailable: Bool { true }

    private var showsPasscodeButton: Bool {
        isLockServiceAvailable && AppLockPasscodeFallbackPolicy.showsPasscodeButton(
            allowPasscodeFallback: settingsVM.allowPasscodeFallback
        )
    }

    var body: some View {
        ZStack {
            VColors.background.ignoresSafeArea()

            VStack(spacing: VSpacing.xxxl) {
                Spacer()

                VStack(spacing: VSpacing.lg) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(VColors.primary)

                    Text(String(localized: "Vittora is Locked"))
                        .font(VTypography.title2)
                        .foregroundStyle(VColors.textPrimary)

                    Text(String(localized: "Authenticate to access your financial data"))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                if cooldownRemaining > 0 {
                    Label(
                        String(localized: "Too many attempts — try again in \(cooldownRemaining)s"),
                        systemImage: "clock"
                    )
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.expense)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.expense)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                Button {
                    Task { await authenticate() }
                } label: {
                    HStack(spacing: VSpacing.sm) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: isLockServiceAvailable ? biometricIcon : "arrow.clockwise")
                        }
                        Text(unlockButtonTitle)
                            .font(VTypography.bodyBold)
                    }
                    .frame(maxWidth: 260)
                    .padding(.vertical, VSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                .disabled(isAuthenticating || cooldownRemaining > 0)
                .accessibilityLabel(unlockButtonTitle)
                .accessibilityHint(unlockButtonHint)

                if showsPasscodeButton {
                    Button(String(localized: "Use Passcode")) {
                        Task { await authenticateWithPasscode() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAuthenticating || cooldownRemaining > 0)
                    .accessibilityHint(String(localized: "Unlocks using your device passcode"))
                }

                Spacer()
            }
        }
        .accessibilityIdentifier("app-lock-root")
        .privacySensitive()
        .task {
            guard isLockServiceAvailable else {
                applyMissingServiceFailClosed()
                return
            }
            await authenticate()
        }
        .task { await runCooldownTimer() }
    }

    private var unlockButtonTitle: String {
        if isAuthenticating { return String(localized: "Authenticating…") }
        if isLockServiceAvailable { return String(localized: "Unlock") }
        return String(localized: "Retry")
    }

    private var unlockButtonHint: String {
        if !isLockServiceAvailable {
            return String(localized: "Retries App Lock after a service error")
        }
        if settingsVM.allowPasscodeFallback {
            return String(localized: "Authenticates using biometrics or passcode")
        }
        return String(localized: "Authenticates using biometrics only")
    }

    private var biometricIcon: String {
        switch dependencies.biometricService.biometricType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        case .opticID:  return "eye"
        case .none:     return "lock.open.fill"
        }
    }

    private func authenticate() async {
        await performAuthentication { lockService in
            try await lockService.unlock(allowPasscodeFallback: settingsVM.allowPasscodeFallback)
        }
    }

    private func authenticateWithPasscode() async {
        await performAuthentication { lockService in
            try await lockService.unlockWithPasscode()
        }
    }

    private func applyMissingServiceFailClosed() {
        let update = AppLockUnlockGate.sessionUpdateAfterMissingService()
        appState.isAuthenticated = update.isAuthenticated
        appState.isLocked = update.isLocked
        errorMessage = AppLockUnlockGate.missingServiceMessage
    }

    private func performAuthentication(
        _ action: @escaping (any AppLockServiceProtocol) async throws -> Bool
    ) async {
        let lockService = dependencies.appLockService
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        do {
            let success = try await action(lockService)
            if success {
                appState.isAuthenticated = true
                appState.isLocked = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Polls the lock service every second to keep the on-screen countdown in sync.
    private func runCooldownTimer() async {
        while !Task.isCancelled {
            if let expires = dependencies.appLockService.cooldownExpiresAt, expires > .now {
                cooldownRemaining = Int(expires.timeIntervalSince(.now).rounded(.up))
            } else {
                cooldownRemaining = 0
            }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }
}
