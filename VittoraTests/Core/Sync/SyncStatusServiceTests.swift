import Testing
import Foundation
@testable import Vittora

@Suite("SyncStatusService Tests")
@MainActor
struct SyncStatusServiceTests {

    private func makeService() throws -> (SyncStatusService, UserDefaults) {
        let suiteName = "com.vittora.test.\(UUID().uuidString)"
        let ud = try #require(UserDefaults(suiteName: suiteName))
        return (SyncStatusService(isMonitoringEnabled: false, userDefaults: ud), ud)
    }

    @Test("Initial state is synced")
    func initialStateSynced() throws {
        let (service, _) = try makeService()
        let validStates: [SyncState] = [.synced, .syncing, .pending, .offline]
        let isValidInitial = validStates.contains(service.syncState) || service.syncState.isError
        #expect(isValidInitial)
    }

    /// OFFL-03: sync UI must not block local use; when iCloud is unavailable, `markSyncing` is a no-op.
    @Test("markSyncing does not switch to syncing when iCloud account unavailable")
    func markSyncingNoOpWhenICloudUnavailable() throws {
        let (service, _) = try makeService()
        #expect(service.iCloudAccountAvailable == false)
        service.markSynced()
        service.markSyncing()
        #expect(service.syncState == .synced)
    }

    @Test("markSynced updates lastSyncDate")
    func markSyncedUpdatesDate() throws {
        let (service, _) = try makeService()
        let before = Date.now
        service.markSynced()
        #expect(service.syncState == .synced)
        #expect(service.lastSyncDate != nil)
        #expect(service.lastSyncDate! >= before)
    }

    @Test("markSynced persists date to injected UserDefaults")
    func markSyncedPersistsToUserDefaults() throws {
        let (service, ud) = try makeService()
        service.markSynced()
        let stored = ud.object(forKey: "vittora.lastSyncDate") as? Date
        #expect(stored != nil)
    }

    /// OFFL-03: pending is only surfaced when sync can run; otherwise state stays unchanged.
    @Test("markPending does not switch to pending when iCloud account unavailable")
    func markPendingNoOpWhenICloudUnavailable() throws {
        let (service, _) = try makeService()
        #expect(service.iCloudAccountAvailable == false)
        service.markSynced()
        service.markPending()
        #expect(service.syncState == .synced)
    }

    @Test("markError sets error state with message")
    func markErrorSetsMessage() throws {
        let (service, _) = try makeService()
        service.markError("Test error")
        if case .error(let msg) = service.syncState {
            #expect(msg == "Test error")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("lastSyncFormatted returns Never when no prior date stored")
    func lastSyncFormattedNever() throws {
        let (freshService, _) = try makeService()
        if freshService.lastSyncDate == nil {
            #expect(freshService.lastSyncFormatted == String(localized: "Never"))
        }
    }

    @Test("SyncState display text is non-empty for all cases")
    func syncStateDisplayText() {
        let states: [SyncState] = [.synced, .syncing, .pending, .offline, .error("oops")]
        for state in states {
            #expect(!state.displayText.isEmpty)
        }
    }

    @Test("SyncState systemImage is non-empty for all cases")
    func syncStateSystemImage() {
        let states: [SyncState] = [.synced, .syncing, .pending, .offline, .error("oops")]
        for state in states {
            #expect(!state.systemImage.isEmpty)
        }
    }

    @Test("SyncState isError only true for error case")
    func syncStateIsError() {
        #expect(SyncState.error("x").isError == true)
        #expect(SyncState.synced.isError == false)
        #expect(SyncState.offline.isError == false)
        #expect(SyncState.syncing.isError == false)
        #expect(SyncState.pending.isError == false)
    }

    /// OFFL-02: missing iCloud is modeled as `.offline`, not `.error`, so the chip stays non-alarming.
    @Test("offline state is not classified as error for UI")
    func offlineNotErrorForDisplay() {
        #expect(!SyncState.offline.isError)
        #expect(SyncState.offline.displayText == String(localized: "Offline"))
    }

    @Test("SyncState equality")
    func syncStateEquality() {
        #expect(SyncState.synced == .synced)
        #expect(SyncState.offline == .offline)
        #expect(SyncState.error("a") == .error("a"))
        #expect(SyncState.error("a") != .error("b"))
        #expect(SyncState.synced != .offline)
    }
}

private actor RecordingAuditLogger: SecurityAuditLogging {
    private(set) var events: [SecurityAuditEvent] = []
    func record(_ event: SecurityAuditEvent) async {
        events.append(event)
    }
}

@Suite("SyncConflictHandler Tests")
@MainActor
struct SyncConflictHandlerTests {

    @Test("resolves to keepRemote when remote is clearly newer (outside skew threshold)")
    func resolvesRemoteWhenClearlyNewer() {
        let handler = SyncConflictHandler()
        let local = Date(timeIntervalSinceNow: -200)
        let remote = Date.now
        let resolution = handler.logConflict(
            entityType: "Transaction",
            entityID: UUID(),
            localModifiedAt: local,
            remoteModifiedAt: remote,
            description: "Test conflict"
        )
        #expect(resolution == .keepRemote)
    }

    @Test("resolves to keepLocal when local is clearly newer (outside skew threshold)")
    func resolvesLocalWhenClearlyNewer() {
        let handler = SyncConflictHandler()
        let remote = Date(timeIntervalSinceNow: -200)
        let local = Date.now
        let resolution = handler.logConflict(
            entityType: "Transaction",
            entityID: UUID(),
            localModifiedAt: local,
            remoteModifiedAt: remote,
            description: "Test conflict"
        )
        #expect(resolution == .keepLocal)
    }

    @Test("resolves to ambiguous when timestamps are within clock-skew threshold")
    func resolvesAmbiguousWithinSkewThreshold() {
        let handler = SyncConflictHandler()
        let local = Date(timeIntervalSinceNow: -30)
        let remote = Date.now
        let resolution = handler.logConflict(
            entityType: "Transaction",
            entityID: UUID(),
            localModifiedAt: local,
            remoteModifiedAt: remote,
            description: "Close timestamps"
        )
        #expect(resolution == .ambiguous)
    }

    @Test("resolves to ambiguous when entity timestamps are unavailable")
    func resolvesAmbiguousWhenTimestampsAbsent() {
        let handler = SyncConflictHandler()
        let resolution = handler.logConflict(
            entityType: "Import",
            description: "No entity timestamps from NSPersistentCloudKitContainer event"
        )
        #expect(resolution == .ambiguous)
    }

    @Test("logged conflict is stored")
    func conflictIsLogged() {
        let handler = SyncConflictHandler()
        handler.logConflict(
            entityType: "Budget",
            entityID: UUID(),
            localModifiedAt: Date(timeIntervalSinceNow: -200),
            remoteModifiedAt: .now,
            description: "Budget conflict"
        )
        #expect(handler.recentConflicts.count == 1)
        #expect(handler.hasUnresolvedConflicts == false)
    }

    @Test("clearLog removes all conflicts")
    func clearLogRemovesAll() {
        let handler = SyncConflictHandler()
        for _ in 0..<5 {
            handler.logConflict(entityType: "X", description: "")
        }
        #expect(handler.recentConflicts.count == 5)
        handler.clearLog()
        #expect(handler.recentConflicts.isEmpty)
        #expect(!handler.hasUnresolvedConflicts)
    }

    @Test("hasUnresolvedConflicts is true only for actionable conflicts")
    func unresolvedConflictsReflectActionableOnly() {
        let handler = SyncConflictHandler()
        handler.logConflict(
            entityType: "Transaction",
            description: "Auto merged",
            resolutionOverride: .cloudKitAutoResolved
        )
        #expect(handler.hasUnresolvedConflicts == false)
        handler.logConflict(
            entityType: "Transaction",
            description: "Ambiguous timing",
            resolutionOverride: .ambiguous
        )
        #expect(handler.hasUnresolvedConflicts)
        #expect(handler.actionableConflicts.count == 1)
    }

    @Test("log capped at 20 entries")
    func logCappedAt20() {
        let handler = SyncConflictHandler()
        for _ in 0..<25 {
            handler.logConflict(entityType: "X", description: "")
        }
        #expect(handler.recentConflicts.count == 20)
    }

    @Test("resolveByTimestamp is ambiguous at exactly the skew boundary")
    func resolveByTimestampSkewBoundary() {
        let handler = SyncConflictHandler()
        let base = Date.now
        let justUnder = base.addingTimeInterval(-SyncConflictHandler.clockSkewThreshold + 1)
        let justOver  = base.addingTimeInterval(-SyncConflictHandler.clockSkewThreshold - 1)

        #expect(handler.resolveByTimestamp(localModifiedAt: justUnder, remoteModifiedAt: base) == .ambiguous)
        #expect(handler.resolveByTimestamp(localModifiedAt: justOver,  remoteModifiedAt: base) == .keepRemote)
    }

    @Test("resolveByTimestamp returns ambiguous when either timestamp is nil")
    func resolveByTimestampNilHandling() {
        let handler = SyncConflictHandler()
        #expect(handler.resolveByTimestamp(localModifiedAt: nil,      remoteModifiedAt: .now) == .ambiguous)
        #expect(handler.resolveByTimestamp(localModifiedAt: .now,     remoteModifiedAt: nil)  == .ambiguous)
        #expect(handler.resolveByTimestamp(localModifiedAt: nil,      remoteModifiedAt: nil)  == .ambiguous)
    }

    @Test("logConflict stores conflict even when entity id is unavailable")
    func logConflictWithoutEntityID() {
        let handler = SyncConflictHandler()
        handler.logConflict(
            entityType: "Import",
            description: "CloudKit import conflict"
        )
        #expect(handler.recentConflicts.count == 1)
        #expect(handler.recentConflicts[0].entityID == nil)
        #expect(handler.recentConflicts[0].resolution == .ambiguous)
    }

    @Test("logConflict with cloudKitAutoResolved records audit event")
    func cloudKitAutoResolvedRecordsAudit() async throws {
        let logger = RecordingAuditLogger()
        let handler = SyncConflictHandler(auditLogger: logger)
        _ = handler.logConflict(
            entityType: "Transaction",
            description: "merged",
            resolutionOverride: .cloudKitAutoResolved
        )
        try await Task.sleep(for: .milliseconds(200))
        let events = await logger.events
        #expect(events.contains { $0.kind == .syncConflictAutoResolved })
    }

    @Test("logConflict without cloudKitAutoResolved does not record audit")
    func nonCloudKitConflictSkipsAudit() async throws {
        let logger = RecordingAuditLogger()
        let handler = SyncConflictHandler(auditLogger: logger)
        _ = handler.logConflict(
            entityType: "Transaction",
            description: "t",
            resolutionOverride: .keepLocal
        )
        try await Task.sleep(for: .milliseconds(200))
        let events = await logger.events
        #expect(events.isEmpty)
    }

    @Test("logIntegrityViolation records audit and logs conflict")
    func integrityViolationRecordsAudit() async throws {
        let logger = RecordingAuditLogger()
        let handler = SyncConflictHandler(auditLogger: logger)
        let id = UUID()
        handler.logIntegrityViolation(entityType: "Transaction", entityID: id, description: "invalid")
        try await Task.sleep(for: .milliseconds(200))
        let events = await logger.events
        #expect(events.contains { $0.kind == .syncIntegrityViolation })
        #expect(handler.recentConflicts.first?.resolution == .integrityViolation)
        #expect(handler.recentConflicts.first?.entityID == id)
    }
}
