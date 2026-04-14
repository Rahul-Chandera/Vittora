import SwiftUI

struct SettingsView: View {
    @State private var vm = SettingsViewModel()

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
            }

            // Data
            Section(String(localized: "Data & Sync")) {
                NavigationLink {
                    SyncSettingsView(vm: vm)
                } label: {
                    SettingsRow(icon: "icloud.fill", iconColor: .blue,
                                title: String(localized: "iCloud Sync"),
                                value: vm.isCloudSyncEnabled ? String(localized: "On") : String(localized: "Off"))
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
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard !parts.isEmpty else { return "V" }
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
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
