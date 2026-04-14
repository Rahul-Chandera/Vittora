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
        }
        .navigationTitle(String(localized: "Security"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "iCloud Sync"), isOn: $vm.isCloudSyncEnabled)
            } footer: {
                Text(String(localized: "Sync your Vittora data across all your Apple devices via iCloud."))
                    .foregroundStyle(VColors.textSecondary)
            }

            Section(String(localized: "Status")) {
                HStack {
                    Text(String(localized: "Last synced"))
                    Spacer()
                    Text(String(localized: "Just now"))
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
        .navigationTitle(String(localized: "iCloud Sync"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section(String(localized: "Export")) {
                Button {
                    // Export handled in future integration
                } label: {
                    Label(String(localized: "Export as CSV"), systemImage: "square.and.arrow.up")
                }
                Button {
                } label: {
                    Label(String(localized: "Export as JSON"), systemImage: "doc.text")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "Delete All Data"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(String(localized: "Manage Data"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            String(localized: "Delete All Data?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Everything"), role: .destructive) {}
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This will permanently erase all your transactions, accounts, budgets, and goals. This cannot be undone."))
        }
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
        }
        .navigationTitle(String(localized: "Notifications"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
                    Text("iOS")
                        .foregroundStyle(VColors.textSecondary)
                    #elseif os(macOS)
                    Text("macOS")
                        .foregroundStyle(VColors.textSecondary)
                    #endif
                }
            }

            Section(String(localized: "Legal")) {
                Link(String(localized: "Privacy Policy"),
                     destination: URL(string: "https://vittora.app/privacy")!)
                Link(String(localized: "Terms of Service"),
                     destination: URL(string: "https://vittora.app/terms")!)
            }

            Section {
                VStack(spacing: VSpacing.sm) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(VColors.primary)
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
