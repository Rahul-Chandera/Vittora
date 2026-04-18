import SwiftUI

struct AppLockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies

    @State private var isAuthenticating = false
    @State private var errorMessage: String?

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

                if let errorMessage {
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
                            Image(systemName: biometricIcon)
                        }
                        Text(isAuthenticating
                             ? String(localized: "Authenticating…")
                             : String(localized: "Unlock"))
                            .font(VTypography.bodyBold)
                    }
                    .frame(maxWidth: 260)
                    .padding(.vertical, VSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                .disabled(isAuthenticating)
                .accessibilityLabel(String(localized: "Unlock Vittora"))
                .accessibilityHint(String(localized: "Authenticates using biometrics or passcode"))

                Button(String(localized: "Use Passcode")) {
                    Task { await authenticateWithPasscode() }
                }
                .buttonStyle(.bordered)
                .disabled(isAuthenticating)
                .accessibilityHint(String(localized: "Unlocks using your device passcode"))

                Spacer()
            }
        }
        .privacySensitive()
        .task { await authenticate() }
    }

    private var biometricIcon: String {
        guard let service = dependencies.biometricService else { return "faceid" }
        switch service.biometricType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        case .opticID:  return "eye"
        case .none:     return "lock.open.fill"
        }
    }

    private func authenticate() async {
        await performAuthentication { lockService in
            try await lockService.unlock()
        }
    }

    private func authenticateWithPasscode() async {
        await performAuthentication { lockService in
            try await lockService.unlockWithPasscode()
        }
    }

    private func performAuthentication(
        _ action: @escaping (any AppLockServiceProtocol) async throws -> Bool
    ) async {
        guard let lockService = dependencies.appLockService else {
            appState.isLocked = false
            return
        }
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
}
