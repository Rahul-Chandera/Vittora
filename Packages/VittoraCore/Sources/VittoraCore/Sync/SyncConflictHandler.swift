import Foundation
import Observation

/// Represents a detected sync conflict between a local and remote version of a record.
public struct SyncConflict: Identifiable, Sendable {
    public let id: UUID
    public let entityType: String
    public let entityID: UUID?
    public let detectedAt: Date
    public let localModifiedAt: Date?
    public let remoteModifiedAt: Date?
    public let description: String
    public let resolution: ConflictResolution
    public var requiresReview: Bool {
        switch resolution {
        case .ambiguous, .integrityViolation:
            true
        case .keepLocal, .keepRemote, .cloudKitAutoResolved:
            false
        }
    }

    public init(
        entityType: String,
        entityID: UUID? = nil,
        detectedAt: Date = .now,
        localModifiedAt: Date? = nil,
        remoteModifiedAt: Date? = nil,
        description: String,
        resolution: ConflictResolution
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityID = entityID
        self.detectedAt = detectedAt
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
        self.description = description
        self.resolution = resolution
    }
}

/// Resolution strategy used when a conflict is detected.
public enum ConflictResolution: Sendable {
    case keepLocal
    case keepRemote
    /// Timestamps are within clock-skew threshold or unknown; system applied its own LWW.
    case ambiguous
    /// CloudKit / Core Data already merged; this entry is advisory (SEC-09).
    case cloudKitAutoResolved
    /// Imported record failed invariant checks — user should review underlying data (SEC-09).
    case integrityViolation
}

/// Handles CloudKit merge conflicts.
///
/// NSPersistentCloudKitContainer applies its own last-writer-wins resolution before this
/// handler is called; the handler logs the event and computes an advisory resolution for
/// display. When entity modification timestamps are unavailable (e.g. from a sync event
/// error) the resolution is `.ambiguous`.
@Observable
@MainActor
public final class SyncConflictHandler: Sendable {
    public private(set) var recentConflicts: [SyncConflict] = []
    private let maxConflictLog = 20
    private let auditLogger: (any SecurityAuditLogging)?

    public static let clockSkewThreshold: TimeInterval = 60

    public init(auditLogger: (any SecurityAuditLogging)? = nil) {
        self.auditLogger = auditLogger
    }

    // MARK: - Conflict resolution

    /// Returns an advisory resolution based on entity modification timestamps.
    /// Returns `.ambiguous` when timestamps are absent or within the clock-skew threshold.
    public func resolveByTimestamp(
        localModifiedAt: Date?,
        remoteModifiedAt: Date?
    ) -> ConflictResolution {
        guard let local = localModifiedAt, let remote = remoteModifiedAt else {
            return .ambiguous
        }
        let delta = abs(remote.timeIntervalSince(local))
        guard delta >= Self.clockSkewThreshold else {
            return .ambiguous
        }
        return remote > local ? .keepRemote : .keepLocal
    }

    /// Logs a detected conflict with an advisory resolution.
    @discardableResult
    public func logConflict(
        entityType: String,
        entityID: UUID? = nil,
        detectedAt: Date = .now,
        localModifiedAt: Date? = nil,
        remoteModifiedAt: Date? = nil,
        description: String,
        resolutionOverride: ConflictResolution? = nil
    ) -> ConflictResolution {
        let resolution = resolutionOverride ?? resolveByTimestamp(
            localModifiedAt: localModifiedAt,
            remoteModifiedAt: remoteModifiedAt
        )
        let conflict = SyncConflict(
            entityType: entityType,
            entityID: entityID,
            detectedAt: detectedAt,
            localModifiedAt: localModifiedAt,
            remoteModifiedAt: remoteModifiedAt,
            description: description,
            resolution: resolution
        )
        appendToLog(conflict)
        if resolution == .cloudKitAutoResolved {
            Task { [auditLogger] in
                await auditLogger?.record(SecurityAuditEvent(
                    kind: .syncConflictAutoResolved,
                    detail: "\(entityType) \(entityID?.uuidString ?? "?"): \(description)"
                ))
            }
        }
        return resolution
    }

    /// Logs a post-merge integrity issue (rejects silently invalid data for user review).
    public func logIntegrityViolation(
        entityType: String,
        entityID: UUID?,
        description: String
    ) {
        let conflict = SyncConflict(
            entityType: entityType,
            entityID: entityID,
            detectedAt: .now,
            localModifiedAt: nil,
            remoteModifiedAt: nil,
            description: description,
            resolution: .integrityViolation
        )
        appendToLog(conflict)
        Task { [auditLogger] in
            await auditLogger?.record(SecurityAuditEvent(
                kind: .syncIntegrityViolation,
                detail: "\(entityType) \(entityID?.uuidString ?? "?"): \(description)"
            ))
        }
    }

    // MARK: - Log management

    private func appendToLog(_ conflict: SyncConflict) {
        recentConflicts.insert(conflict, at: 0)
        if recentConflicts.count > maxConflictLog {
            recentConflicts = Array(recentConflicts.prefix(maxConflictLog))
        }
    }

    public func clearLog() {
        recentConflicts.removeAll()
    }

    public var actionableConflicts: [SyncConflict] { recentConflicts.filter(\.requiresReview) }
    public var hasActionableConflicts: Bool { !actionableConflicts.isEmpty }
    public var hasUnresolvedConflicts: Bool { hasActionableConflicts }
}
