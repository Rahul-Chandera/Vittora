import SwiftUI

/// Compact inline sync indicator — shown in navigation bars.
struct SyncStatusView: View {
    @Environment(SyncStatusService.self) private var syncService

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if syncService.syncState == .syncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(iconColor)
                } else {
                    Image(systemName: syncService.syncState.systemImage)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: 16)

            Text(syncService.syncState.displayText)
                .font(VTypography.caption2)
                .foregroundStyle(iconColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Sync status: \(syncService.syncState.displayText)"))
    }

    private var iconColor: Color {
        switch syncService.syncState {
        case .synced:   return VColors.income
        case .syncing:  return VColors.primary
        case .pending:  return VColors.textSecondary
        case .offline:  return VColors.textTertiary
        case .error:    return VColors.expense
        }
    }
}

/// Full-page sync detail — used in SyncSettingsView.
struct SyncDetailView: View {
    @Environment(SyncStatusService.self) private var syncService

    var body: some View {
        Form {
            Section {
                HStack {
                    SyncStatusView()
                    Spacer()
                    Button(String(localized: "Refresh")) {
                        Task { await syncService.checkiCloudStatus() }
                    }
                    .font(VTypography.caption1)
                }

                HStack {
                    Text(String(localized: "Last synced"))
                    Spacer()
                    Text(syncService.lastSyncFormatted)
                        .foregroundStyle(VColors.textSecondary)
                }

                HStack {
                    Text(String(localized: "iCloud account"))
                    Spacer()
                    Text(syncService.iCloudAccountAvailable
                         ? String(localized: "Connected")
                         : String(localized: "Unavailable"))
                        .foregroundStyle(syncService.iCloudAccountAvailable
                                         ? VColors.income
                                         : VColors.expense)
                }
            } header: {
                Text(String(localized: "Status"))
            }

            if case .error(let msg) = syncService.syncState {
                Section {
                    HStack(spacing: VSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VColors.expense)
                        Text(msg)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                    }
                } header: {
                    Text(String(localized: "Error"))
                }
            }

            Section {
                Text(String(localized: "Vittora uses CloudKit to automatically sync your data across all your Apple devices signed into the same iCloud account. No manual steps needed."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            } header: {
                Text(String(localized: "About iCloud Sync"))
            }
        }
        .navigationTitle(String(localized: "iCloud Sync"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
