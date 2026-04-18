import SwiftUI

/// Compact inline sync indicator — shown in navigation bars.
struct SyncStatusView: View {
    @Environment(SyncStatusService.self) private var syncService
    @Environment(SyncConflictHandler.self) private var syncConflictHandler

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if syncService.syncState == .syncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(iconColor)
                } else {
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: 16)

            Text(statusText)
                .font(VTypography.caption2)
                .foregroundStyle(iconColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Sync status: \(statusText)"))
    }

    private var needsConflictReview: Bool {
        syncConflictHandler.hasUnresolvedConflicts && syncService.syncState != .syncing
    }

    private var statusText: String {
        needsConflictReview ? String(localized: "Review") : syncService.syncState.displayText
    }

    private var iconName: String {
        needsConflictReview ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90" : syncService.syncState.systemImage
    }

    private var iconColor: Color {
        if needsConflictReview { return VColors.warning }
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
    @Environment(SyncConflictHandler.self) private var syncConflictHandler

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
                VStack(alignment: .leading, spacing: VSpacing.sm) {
                    Text(String(localized: "CloudKit resolves conflicts automatically"))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "When iCloud detects a merge conflict it applies its own last-writer-wins strategy. Vittora logs each event here. When modification timestamps are close together or unavailable, the outcome is shown as ambiguous."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
                .padding(.vertical, 2)
            } header: {
                Text(String(localized: "Conflict Handling"))
            } footer: {
                Text(String(localized: "The conflict log keeps the 20 most recent events. Conflicts within 60 seconds of each other are flagged as ambiguous due to possible clock skew."))
                    .foregroundStyle(VColors.textSecondary)
            }

            Section {
                if syncConflictHandler.recentConflicts.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "No recent sync conflicts"))
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.textPrimary)
                            Text(String(localized: "Recent iCloud merges have completed without any logged conflicts."))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(VColors.income)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text(String(localized: "\(syncConflictHandler.recentConflicts.count) recent sync conflicts were resolved automatically."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)

                    ForEach(syncConflictHandler.recentConflicts) { conflict in
                        SyncConflictReviewRow(conflict: conflict)
                    }

                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            syncConflictHandler.clearLog()
                        }
                    } label: {
                        Label(String(localized: "Clear Reviewed Conflicts"), systemImage: "trash")
                    }
                }
            } header: {
                Text(String(localized: "Conflict Review"))
            } footer: {
                Text(String(localized: "The current CloudKit integration logs timestamps and outcomes for automatic resolutions. More detailed record snapshots can be added later without changing this review flow."))
                    .foregroundStyle(VColors.textSecondary)
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

private struct SyncConflictReviewRow: View {
    let conflict: SyncConflict

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .top, spacing: VSpacing.sm) {
                Image(systemName: resolutionIcon)
                    .foregroundStyle(resolutionColor)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.entityType)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(resolutionTitle)
                        .font(VTypography.caption1)
                        .foregroundStyle(resolutionColor)
                }

                Spacer()

                if let entityID = conflict.entityID {
                    Text(shortID(for: entityID))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textTertiary)
                }
            }

            Text(conflict.description)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                metadataRow(
                    title: String(localized: "Detected"),
                    value: conflict.detectedAt.formatted(date: .abbreviated, time: .shortened),
                    isHighlighted: false
                )
                if let local = conflict.localModifiedAt {
                    metadataRow(
                        title: String(localized: "Local modified"),
                        value: local.formatted(date: .abbreviated, time: .shortened),
                        isHighlighted: conflict.resolution == .keepLocal
                    )
                }
                if let remote = conflict.remoteModifiedAt {
                    metadataRow(
                        title: String(localized: "Remote modified"),
                        value: remote.formatted(date: .abbreviated, time: .shortened),
                        isHighlighted: conflict.resolution == .keepRemote
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var resolutionTitle: String {
        switch conflict.resolution {
        case .keepLocal:
            String(localized: "Local version kept")
        case .keepRemote:
            String(localized: "Remote version kept")
        case .ambiguous:
            String(localized: "System applied LWW (outcome ambiguous)")
        }
    }

    private var resolutionIcon: String {
        switch conflict.resolution {
        case .keepLocal:
            "iphone.and.arrow.forward"
        case .keepRemote:
            "icloud.and.arrow.down"
        case .ambiguous:
            "questionmark.circle"
        }
    }

    private var resolutionColor: Color {
        switch conflict.resolution {
        case .keepLocal:
            VColors.primary
        case .keepRemote:
            VColors.warning
        case .ambiguous:
            VColors.textSecondary
        }
    }

    @ViewBuilder
    private func metadataRow(title: String, value: String, isHighlighted: Bool) -> some View {
        HStack {
            Text(title)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textTertiary)
            Spacer()
            Text(value)
                .font(VTypography.caption1)
                .foregroundStyle(isHighlighted ? resolutionColor : VColors.textSecondary)
        }
        .padding(.horizontal, VSpacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                .fill(isHighlighted ? resolutionColor.opacity(0.12) : VColors.tertiaryBackground)
        )
    }

    private func shortID(for id: UUID) -> String {
        let raw = id.uuidString
        return String(raw.prefix(8)).uppercased()
    }
}
