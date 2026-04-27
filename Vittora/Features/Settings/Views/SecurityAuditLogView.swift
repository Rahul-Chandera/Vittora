import SwiftUI

/// Read-only view of encrypted security audit entries (SEC-18).
struct SecurityAuditLogView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var entries: [SecurityAuditLogEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    String(localized: "No audit entries yet"),
                    systemImage: "list.bullet.rectangle",
                    description: Text(String(localized: "Lock, unlock, exports, and sync events appear here."))
                )
            } else {
                List(entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(displayTitle(for: entry.kind))
                            .font(VTypography.bodyBold)
                        Text(entry.detail)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(String(localized: "Security audit log"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadEntries() }
    }

    private func loadEntries() async {
        guard let svc = dependencies.securityAuditLogService else {
            entries = []
            return
        }
        entries = await svc.recentEntries(limit: 100)
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
