import SwiftUI
import VittoraCore

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var vm
    @Environment(SyncConflictHandler.self) private var syncConflictHandler
    @Environment(SyncStatusService.self) private var syncService
    @Environment(\.dependencies) private var dependencies
    @State private var showDeleteAccountConfirm = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAllData = false
    @State private var deleteAllDataError: String?
    @State private var showRestartAfterRecoveryReset = false
    @State private var showContactSupport = false

    private let deleteConfirmationPhrase = String(localized: "DELETE")

    var body: some View {
        Form {
            // Profile
            Section {
                NavigationLink {
                    ProfileSettingsView(vm: vm)
                } label: {
                    HStack(spacing: VSpacing.md) {
                        Circle()
                            .fill(VColors.primary.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Text(initials(vm.userName))
                                    .font(VTypography.title3.bold())
                                    .foregroundStyle(VColors.primary)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.userName.isEmpty ? String(localized: "Your Name") : vm.userName)
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.textPrimary)
                            Text(String(localized: "Edit profile"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Preferences
            Section(String(localized: "Preferences")) {
                Button {
                    showContactSupport = true
                } label: {
                    SettingsRow(icon: "envelope.fill", iconColor: .green,
                                title: String(localized: "Contact Support"), value: "")
                }
                .accessibilityIdentifier("settings-contact-support")
                NavigationLink {
                    CurrencySettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "dollarsign.circle.fill", iconColor: .green,
                                title: String(localized: "Currency"),
                                value: vm.selectedCurrencyCode)
                }
                NavigationLink {
                    AppearanceSettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "paintpalette.fill", iconColor: .purple,
                                title: String(localized: "Appearance"),
                                value: vm.appearanceMode.displayName)
                }
            }

            // Manage
            Section(String(localized: "Manage")) {
                NavigationLink {
                    AccountListView()
                } label: {
                    SettingsRow(icon: "building.columns.fill", iconColor: .blue,
                                title: String(localized: "Accounts"), value: "")
                }
                .accessibilityIdentifier("settings-manage-accounts")
                NavigationLink {
                    CategoryListView()
                } label: {
                    SettingsRow(icon: "tag.fill", iconColor: .pink,
                                title: String(localized: "Categories"), value: "")
                }
                .accessibilityIdentifier("settings-manage-categories")
                NavigationLink {
                    PayeeListView()
                } label: {
                    SettingsRow(icon: "person.2.fill", iconColor: .teal,
                                title: String(localized: "Payees"), value: "")
                }
                .accessibilityIdentifier("settings-manage-payees")
                NavigationLink {
                    RecurringListView()
                } label: {
                    SettingsRow(icon: "arrow.triangle.2.circlepath", iconColor: .indigo,
                                title: String(localized: "Recurring"), value: "")
                }
                .accessibilityIdentifier("settings-manage-recurring")
            }

            // Security
            Section(String(localized: "Security")) {
                NavigationLink {
                    SecuritySettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "lock.fill", iconColor: .orange,
                                title: String(localized: "App Lock"),
                                value: vm.isAppLockEnabled ? String(localized: "On") : String(localized: "Off"))
                }
                NavigationLink {
                    PrivacySearchSettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "magnifyingglass", iconColor: .cyan,
                                title: String(localized: "Search Privacy"),
                                value: vm.isSpotlightIndexingEnabled ? String(localized: "On") : String(localized: "Off"))
                }
                NavigationLink {
                    SecurityAuditLogView()
                } label: {
                    SettingsRow(icon: "list.bullet.rectangle", iconColor: .gray,
                                title: String(localized: "Security audit log"), value: "")
                }
            }

            // Data
            Section(String(localized: "Data & Sync")) {
                NavigationLink {
                    SyncSettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "icloud.fill", iconColor: .blue,
                                title: String(localized: "iCloud Sync"),
                                value: syncValue)
                }
                NavigationLink {
                    DataSettingsView()
                } label: {
                    SettingsRow(icon: "cylinder.split.1x2.fill", iconColor: .gray,
                                title: String(localized: "Manage Data"), value: "")
                }
            }

            // Notifications
            Section {
                NavigationLink {
                    NotificationsSettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "bell.fill", iconColor: .red,
                                title: String(localized: "Notifications"),
                                value: vm.isNotificationsEnabled ? String(localized: "On") : String(localized: "Off"))
                }
            }

            // Account deletion
            Section {
                Button(role: .destructive) {
                    deleteConfirmationText = ""
                    showDeleteAccountConfirm = true
                } label: {
                    SettingsRow(icon: "trash.fill", iconColor: .red,
                                title: String(localized: "Delete All Data"),
                                value: "")
                }
            } footer: {
                Text(String(localized: "Permanently deletes all financial data and resets the app."))
                    .foregroundStyle(VColors.textSecondary)
            }

            // About
            Section(String(localized: "About")) {
                NavigationLink {
                    AboutView(vm: vm)
                } label: {
                    SettingsRow(icon: "info.circle.fill", iconColor: .blue,
                                title: String(localized: "About Vittora"), value: "v\(vm.appVersion)")
                }
            }
        }
        .navigationTitle(String(localized: "Settings"))
        .errorAlert(message: Binding(
            get: { vm.keychainError },
            set: { vm.keychainError = $0 }
        ))
        .sheet(isPresented: $showDeleteAccountConfirm, onDismiss: {
            deleteConfirmationText = ""
            deleteAllDataError = nil
        }) {
            deleteAllDataConfirmationSheet
        }
        .sheet(isPresented: $showContactSupport) {
            NavigationStack {
                ContactSupportView(
                    settingsVM: vm,
                    dependencies: dependencies,
                    syncService: syncService
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) {
                            showContactSupport = false
                        }
                    }
                }
            }
        }
        .alert(
            String(localized: "Data Erased"),
            isPresented: $showRestartAfterRecoveryReset
        ) {
            #if os(macOS)
            Button(String(localized: "Quit Vittora")) {
                NSApp.terminate(nil)
            }
            #endif
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Quit and reopen Vittora to finish leaving recovery mode with a fresh data store."))
        }
    }

    private var deleteAllDataConfirmationSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "This permanently erases all financial data, removes saved settings, and resets Vittora to its initial state. This cannot be undone."))
                        .foregroundStyle(VColors.textPrimary)
                }

                Section(String(localized: "Confirmation")) {
                    Text(String(localized: "Type \(deleteConfirmationPhrase) to confirm."))
                        .foregroundStyle(VColors.textSecondary)

                    TextField(deleteConfirmationPhrase, text: $deleteConfirmationText)
                        // On macOS the grouped form renders the title as a
                        // redundant leading label next to the caption above.
                        .labelsHidden()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()

                    if !deleteConfirmationText.isEmpty && !canConfirmDeleteAllData {
                        VInlineErrorText(String(localized: "The confirmation text must match exactly."))
                    }
                }

                // Errors must render inside the sheet: the errorAlert on the
                // underlying SettingsView cannot present while this sheet is up,
                // so routing failures there swallows them silently.
                if let deleteAllDataError {
                    Section {
                        VInlineErrorText(deleteAllDataError)
                    }
                }
            }
            .navigationTitle(String(localized: "Delete All Data"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        showDeleteAccountConfirm = false
                    }
                    .disabled(isDeletingAllData)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Permanently Delete"), role: .destructive) {
                        Task { await confirmDeleteAllData() }
                    }
                    .disabled(!canConfirmDeleteAllData || isDeletingAllData)
                }
            }
        }
    }

    private var canConfirmDeleteAllData: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == deleteConfirmationPhrase
    }

    private func confirmDeleteAllData() async {
        isDeletingAllData = true
        deleteAllDataError = nil
        defer { isDeletingAllData = false }

        do {
            guard try await SensitiveActionAuthenticator.confirm(
                action: .factoryReset,
                using: dependencies.biometricService
            ) else {
                return
            }
        } catch {
            deleteAllDataError = error.localizedDescription
            return
        }

        let didDelete = await deleteAllData()
        if didDelete {
            resetRuntimeStateAfterFactoryReset()
            showDeleteAccountConfirm = false
            if appState.isRecoveryMode {
                showRestartAfterRecoveryReset = true
            }
        }
    }

    private func resetRuntimeStateAfterFactoryReset() {
        // Factory reset clears persisted onboarding/security markers.
        // Reset in-memory state as well so the app immediately returns to onboarding.
        vm.resetKeychainBackedPreferencesInMemory()
        appState.isLocked = false
        appState.isAuthenticated = true
        appState.isOnboardingComplete = false
        appState.selectedTab = .dashboard
    }

    private func deleteAllData() async -> Bool {
        let service = dependencies.makeDataManagementService()
        do {
            // In recovery mode the repositories only clear the in-memory
            // container; the unopenable on-disk store must be deleted too or
            // the next launch lands straight back in recovery.
            try await service.factoryReset(alsoDestroyOnDiskStore: appState.isRecoveryMode)
            return true
        } catch {
            deleteAllDataError = error.localizedDescription
            return false
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard !parts.isEmpty else { return "V" }
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    private var syncValue: String {
        if syncConflictHandler.hasActionableConflicts {
            return String(localized: "Review")
        }
        return vm.isCloudSyncEnabled ? String(localized: "On") : String(localized: "Off")
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: VSpacing.md) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            Text(title)
                .foregroundStyle(VColors.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .foregroundStyle(VColors.textSecondary)
                    .font(VTypography.caption1)
            }
        }
    }
}
