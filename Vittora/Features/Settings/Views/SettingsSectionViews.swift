import SwiftUI
import VittoraCore

// MARK: - Profile Settings

struct ProfileSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @State private var editingName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(String(localized: "Display Name")) {
                TextField(String(localized: "Your name"), text: $editingName)
                    #if os(iOS)
                    .textContentType(.name)
                    #endif
            }
        }
        .navigationTitle(String(localized: "Profile"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { editingName = vm.userName }
        .onChange(of: editingName) { _, new in
            Task { await vm.updateUserName(new) }
        }
    }
}

// MARK: - Currency Settings

struct CurrencySettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section(String(localized: "Select Currency")) {
                ForEach(vm.supportedCurrencies, id: \.code) { currency in
                    Button {
                        vm.selectedCurrencyCode = currency.code
                    } label: {
                        HStack {
                            Text(currency.name)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if vm.selectedCurrencyCode == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.primary)
                            }
                        }
                        // Make the whole row tappable, not just the text.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(String(localized: "Currency"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section(String(localized: "Theme")) {
                ForEach(SettingsViewModel.AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        vm.appearanceMode = mode
                    } label: {
                        HStack {
                            Text(mode.displayName)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if vm.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.primary)
                            }
                        }
                        // Make the whole row tappable, not just the text.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(String(localized: "Appearance"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDisablingAppLock = false

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { vm.isAppLockEnabled },
            set: { newValue in
                if newValue {
                    Task { await vm.updateAppLockEnabled(true) }
                } else {
                    Task { await disableAppLockIfNeeded() }
                }
            }
        )
    }

    private var passcodeFallbackBinding: Binding<Bool> {
        Binding(
            get: { vm.allowPasscodeFallback },
            set: { newValue in
                Task { await vm.updateAllowPasscodeFallback(newValue) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "App Lock"), isOn: appLockBinding)
                    .disabled(isDisablingAppLock)
            } footer: {
                Text(String(localized: "Require biometrics or passcode when opening Vittora."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isAppLockEnabled {
                Section {
                    ForEach(AppLockTimeout.allCases, id: \.self) { timeout in
                        Button {
                            vm.appLockTimeout = timeout
                        } label: {
                            HStack {
                                Text(timeout.displayName)
                                    .foregroundStyle(VColors.textPrimary)
                                Spacer()
                                if vm.appLockTimeout == timeout {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(VColors.primary)
                                }
                            }
                            // Make the whole row tappable, not just the text.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(String(localized: "Lock After"))
                } footer: {
                    Text(String(localized: "Require authentication again after the app has been in the background for this long."))
                        .foregroundStyle(VColors.textSecondary)
                }

                Section {
                    Toggle(String(localized: "Passcode Fallback"), isOn: passcodeFallbackBinding)
                } footer: {
                    Text(String(localized: "Allow your device passcode if biometric authentication fails."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }

            if DeviceSecurityAssessment.isLikelyCompromisedEnvironment {
                Section {
                    Label {
                        Text(String(localized: "Modified device environment detected"))
                            .font(VTypography.caption1)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VColors.warning)
                    }
                } footer: {
                    Text(String(localized: "For your security, avoid storing highly sensitive data on modified devices. This check is informational only."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
        .navigationTitle(String(localized: "Security"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(reduceMotion ? nil : .default, value: vm.isAppLockEnabled)
    }

    private func disableAppLockIfNeeded() async {
        guard vm.isAppLockEnabled else { return }
        isDisablingAppLock = true
        defer { isDisablingAppLock = false }
        _ = await vm.disableAppLockIfAuthenticated(using: dependencies.biometricService)
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        SyncDetailView()
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    var body: some View {
        DataManagementView()
    }
}

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isApplyingMasterToggle = false
    @State private var permissionDeniedMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "Enable Notifications"),
                    isOn: Binding(
                        get: { vm.isNotificationsEnabled },
                        set: { newValue in
                            Task { await handleMasterToggle(enabled: newValue) }
                        }
                    )
                )
                .disabled(isApplyingMasterToggle)
            } footer: {
                Text(String(localized: "Receive reminders for bill due dates, budget limits, and goal milestones."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isNotificationsEnabled {
                Section(String(localized: "Reminders")) {
                    Toggle(String(localized: "Bill & Debt Due Dates"), isOn: $vm.notifyBillsDue)
                        .onChange(of: vm.notifyBillsDue) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Budget Limit Alerts"), isOn: $vm.notifyBudgetAlerts)
                        .onChange(of: vm.notifyBudgetAlerts) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Goal Milestones"), isOn: $vm.notifyGoalMilestones)
                        .onChange(of: vm.notifyGoalMilestones) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Recurring Transactions"), isOn: $vm.notifyRecurringTransactions)
                        .onChange(of: vm.notifyRecurringTransactions) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                }
            }
        }
        .navigationTitle(String(localized: "Notifications"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(reduceMotion ? nil : .default, value: vm.isNotificationsEnabled)
        .alert(
            String(localized: "Notifications Unavailable"),
            isPresented: Binding(
                get: { permissionDeniedMessage != nil },
                set: { if !$0 { permissionDeniedMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                permissionDeniedMessage = nil
            }
        } message: {
            if let permissionDeniedMessage {
                Text(permissionDeniedMessage)
            }
        }
    }

    private func notificationPreferencesUseCase() -> ApplyNotificationPreferencesUseCase {
        ApplyNotificationPreferencesUseCase(
            notificationService: dependencies.notificationService,
            refreshAllSchedules: { @MainActor in
                await dependencies.refreshAllNotificationSchedules()
            }
        )
    }

    @MainActor
    private func handleMasterToggle(enabled: Bool) async {
        let useCase = notificationPreferencesUseCase()

        isApplyingMasterToggle = true
        defer { isApplyingMasterToggle = false }

        if enabled {
            do {
                let granted = try await useCase.enableNotifications()
                vm.isNotificationsEnabled = granted
                if !granted {
                    permissionDeniedMessage = String(
                        localized: "Notification permission was denied. Enable notifications in System Settings to receive reminders."
                    )
                }
            } catch {
                vm.isNotificationsEnabled = false
                permissionDeniedMessage = error.localizedDescription
            }
        } else {
            await useCase.disableNotifications()
            vm.isNotificationsEnabled = false
        }
    }

    @MainActor
    private func applySubToggleChange() async {
        await notificationPreferencesUseCase().applySubToggleChange()
    }
}

// MARK: - About View

struct AboutView: View {
    let vm: SettingsViewModel

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(localized: "Version"))
                    Spacer()
                    Text("v\(vm.appVersion) (\(vm.buildNumber))")
                        .foregroundStyle(VColors.textSecondary)
                }
                HStack {
                    Text(String(localized: "Platform"))
                    Spacer()
                    #if os(iOS)
                    Text(String(localized: "iOS"))
                        .foregroundStyle(VColors.textSecondary)
                    #elseif os(macOS)
                    Text(String(localized: "macOS"))
                        .foregroundStyle(VColors.textSecondary)
                    #endif
                }
            }

            Section(String(localized: "Legal")) {
                NavigationLink(String(localized: "Privacy Policy")) {
                    LegalDocumentView(document: .privacyPolicy)
                }
                NavigationLink(String(localized: "Terms of Service")) {
                    LegalDocumentView(document: .termsOfService)
                }
            }

            Section {
                VStack(spacing: VSpacing.sm) {
                    Image("OnboardingAppLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    Text(String(localized: "Vittora"))
                        .font(VTypography.title3.bold())
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Your personal finance companion"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VSpacing.md)
            }
        }
        .navigationTitle(String(localized: "About Vittora"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
