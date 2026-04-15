import Foundation

/// Represents a detected sync conflict between a local and remote version of a record.
struct SyncConflict: Identifiable, Sendable {
    let id: UUID
    let entityType: String
    let entityID: UUID?
    let localTimestamp: Date
    let remoteTimestamp: Date
    let description: String

    init(
        entityType: String,
        entityID: UUID? = nil,
        localTimestamp: Date,
        remoteTimestamp: Date,
        description: String
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityID = entityID
        self.localTimestamp = localTimestamp
        self.remoteTimestamp = remoteTimestamp
        self.description = description
    }
}

/// Resolution strategy used when a conflict is detected.
enum ConflictResolution: Sendable {
    case keepLocal
    case keepRemote  // last-writer-wins default
}

/// Handles CloudKit merge conflicts using last-writer-wins strategy.
/// Logs conflicts for user review and provides notification support.
@Observable
@MainActor
final class SyncConflictHandler: Sendable {
    private(set) var recentConflicts: [SyncConflict] = []
    private let maxConflictLog = 20

    // MARK: - Conflict resolution

    /// Resolves a conflict using last-writer-wins (most recent timestamp wins).
    /// Returns the resolution decision and records it in the log.
    @discardableResult
    func resolve(_ conflict: SyncConflict) -> ConflictResolution {
        let resolution: ConflictResolution = conflict.remoteTimestamp > conflict.localTimestamp
            ? .keepRemote
            : .keepLocal

        appendToLog(conflict)
        return resolution
    }

    /// Convenience: resolve by comparing two dates directly.
    /// Returns `.keepRemote` if remote is newer (last-writer-wins).
    func resolveByTimestamp(localUpdatedAt: Date, remoteUpdatedAt: Date) -> ConflictResolution {
        remoteUpdatedAt > localUpdatedAt ? .keepRemote : .keepLocal
    }

    /// Logs a detected conflict and applies the default resolution strategy.
    @discardableResult
    func logConflict(
        entityType: String,
        entityID: UUID? = nil,
        localTimestamp: Date,
        remoteTimestamp: Date,
        description: String
    ) -> ConflictResolution {
        let conflict = SyncConflict(
            entityType: entityType,
            entityID: entityID,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp,
            description: description
        )
        return resolve(conflict)
    }

    // MARK: - Log management

    private func appendToLog(_ conflict: SyncConflict) {
        recentConflicts.insert(conflict, at: 0)
        if recentConflicts.count > maxConflictLog {
            recentConflicts = Array(recentConflicts.prefix(maxConflictLog))
        }
    }

    func clearLog() {
        recentConflicts.removeAll()
    }

    var hasUnresolvedConflicts: Bool { !recentConflicts.isEmpty }
}
