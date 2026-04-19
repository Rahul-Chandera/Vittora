import SwiftUI

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
        .onChange(of: editingName) { _, new in vm.userName = new }
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

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "App Lock"), isOn: $vm.isAppLockEnabled)
            } footer: {
                Text(String(localized: "Require biometrics or passcode when opening Vittora."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isAppLockEnabled {
                Section {
                    Toggle(String(localized: "Passcode Fallback"), isOn: $vm.allowPasscodeFallback)
                } footer: {
                    Text(String(localized: "Allow your device passcode if biometric authentication fails."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
        .navigationTitle(String(localized: "Security"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(.default, value: vm.isAppLockEnabled)
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

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Enable Notifications"), isOn: $vm.isNotificationsEnabled)
            } footer: {
                Text(String(localized: "Receive reminders for bill due dates, budget limits, and goal milestones."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isNotificationsEnabled {
                Section(String(localized: "Reminders")) {
                    Toggle(String(localized: "Bill & Debt Due Dates"), isOn: $vm.notifyBillsDue)
                    Toggle(String(localized: "Budget Limit Alerts"), isOn: $vm.notifyBudgetAlerts)
                    Toggle(String(localized: "Goal Milestones"), isOn: $vm.notifyGoalMilestones)
                    Toggle(String(localized: "Recurring Transactions"), isOn: $vm.notifyRecurringTransactions)
                }
            }
        }
        .navigationTitle(String(localized: "Notifications"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(.default, value: vm.isNotificationsEnabled)
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
                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(VColors.primary)
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
