import SwiftUI

struct SettingsView: View {
    @State private var vm = SettingsViewModel()
    @Environment(SyncConflictHandler.self) private var syncConflictHandler
    @Environment(\.dependencies) private var dependencies
    @State private var showDeleteAccountConfirm = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAllData = false

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
                            Text(String(localized: "Tap to edit profile"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Preferences
            Section(String(localized: "Preferences")) {
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
        .sheet(isPresented: $showDeleteAccountConfirm) {
            deleteAllDataConfirmationSheet
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
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()

                    if !deleteConfirmationText.isEmpty && !canConfirmDeleteAllData {
                        VInlineErrorText(String(localized: "The confirmation text must match exactly."))
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
        let didDelete = await deleteAllData()
        isDeletingAllData = false

        if didDelete {
            showDeleteAccountConfirm = false
        }
    }

    private func deleteAllData() async -> Bool {
        guard let txRepo = dependencies.transactionRepository,
              let accRepo = dependencies.accountRepository,
              let catRepo = dependencies.categoryRepository,
              let budRepo = dependencies.budgetRepository,
              let debtRepo = dependencies.debtRepository,
              let goalRepo = dependencies.savingsGoalRepository,
              let splitRepo = dependencies.splitGroupRepository,
              let docRepo = dependencies.documentRepository else {
            vm.keychainError = String(localized: "We couldn't access the data store to delete your data.")
            return false
        }
        let service = DataManagementService(
            transactionRepository: txRepo,
            accountRepository: accRepo,
            categoryRepository: catRepo,
            budgetRepository: budRepo,
            debtRepository: debtRepo,
            savingsGoalRepository: goalRepo,
            splitGroupRepository: splitRepo,
            documentRepository: docRepo,
            keychainService: dependencies.keychainService ?? KeychainService()
        )
        do {
            try await service.factoryReset()
            return true
        } catch {
            vm.keychainError = error.localizedDescription
            return false
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard !parts.isEmpty else { return "V" }
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    private var syncValue: String {
        if syncConflictHandler.hasUnresolvedConflicts {
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
