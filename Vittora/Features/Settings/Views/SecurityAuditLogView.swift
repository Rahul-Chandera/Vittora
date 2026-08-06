import SwiftUI
import VittoraCore

/// Read-only view of encrypted security audit entries (SEC-18).
struct SecurityAuditLogView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var entries: [SecurityAuditLogEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: VSpacing.md) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(VTypography.largeTitle)
                        .foregroundStyle(VColors.textPrimary)
                        .accessibilityHidden(true)
                    Text(String(localized: "No audit entries yet"))
                        .font(VTypography.title2)
                        .foregroundStyle(VColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(String(localized: "Lock, unlock, exports, and sync events appear here."))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(VSpacing.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VColors.background)
            } else {
                List(entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(displayTitle(for: entry.kind))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                        Text(entry.detail)
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                        Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        // Clearance for the floating tab bar. safeAreaPadding, not
        // safeAreaInset: an inset places an actual view, and an opaque
        // one masks whatever scrolls behind it — which is the banner
        // that showed above the tab bar. Padding just extends the
        // scrollable area so content can clear the bar on its own.
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(String(localized: "Security audit log"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadEntries() }
    }

    private func loadEntries() async {
        entries = await dependencies.securityAuditLogService.recentEntries(limit: 100)
    }

    private func displayTitle(for kind: SecurityAuditEventKind) -> String {
        switch kind {
        case .appLocked: return String(localized: "App locked")
        case .appUnlocked: return String(localized: "App unlocked")
        case .exportCreated: return String(localized: "Export created")
        case .syncConflictAutoResolved: return String(localized: "Sync conflict resolved")
        case .syncIntegrityViolation: return String(localized: "Sync integrity issue")
        case .encryptionKeyRotated: return String(localized: "Encryption key rotated")
        }
    }
}
