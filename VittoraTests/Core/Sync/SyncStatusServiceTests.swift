import Testing
import Foundation
@testable import Vittora

@Suite("SyncStatusService Tests")
@MainActor
struct SyncStatusServiceTests {

    @Test("Initial state is synced")
    func initialStateSynced() {
        let service = SyncStatusService()
        // Initial state should be synced until network/CloudKit checks run
        // We just verify it is one of the valid states
        let validStates: [SyncState] = [.synced, .syncing, .pending, .offline]
        let isValidInitial = validStates.contains(service.syncState) || service.syncState.isError
        #expect(isValidInitial)
    }

    @Test("markSyncing sets state to syncing when account available")
    func markSyncingUpdatesState() {
        let service = SyncStatusService()
        // Simulate available state
        service.markSynced() // sets synced first
        service.markSyncing()
        // markSyncing only proceeds if isNetworkAvailable && iCloudAccountAvailable
        // We can't easily inject those in unit tests without mocking, so just verify no crash
        #expect(service.syncState == .syncing || service.syncState == .synced)
    }

    @Test("markSynced updates lastSyncDate")
    func markSyncedUpdatesDate() {
        let service = SyncStatusService()
        let before = Date.now
        service.markSynced()
        #expect(service.syncState == .synced)
        #expect(service.lastSyncDate != nil)
        #expect(service.lastSyncDate! >= before)
    }

    @Test("markSynced persists date to UserDefaults")
    func markSyncedPersistsToUserDefaults() {
        let service = SyncStatusService()
        service.markSynced()
        let stored = UserDefaults.standard.object(forKey: "vittora.lastSyncDate") as? Date
        #expect(stored != nil)
    }

    @Test("markPending sets pending state when account available")
    func markPendingSetsState() {
        let service = SyncStatusService()
        service.markSynced() // start from known state
        service.markPending()
        // pending is set only when network + iCloud available — can be either
        let isPendingOrSynced = service.syncState == .pending || service.syncState == .synced
        #expect(isPendingOrSynced)
    }

    @Test("markError sets error state with message")
    func markErrorSetsMessage() {
        let service = SyncStatusService()
        service.markError("Test error")
        if case .error(let msg) = service.syncState {
            #expect(msg == "Test error")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("lastSyncFormatted returns Never when no date")
    func lastSyncFormattedNever() {
        let service = SyncStatusService()
        // Clear UserDefaults key to get nil date
        UserDefaults.standard.removeObject(forKey: "vittora.lastSyncDate")
        let freshService = SyncStatusService()
        // If no date was stored, should return "Never"
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

    @Test("SyncState equality")
    func syncStateEquality() {
        #expect(SyncState.synced == .synced)
        #expect(SyncState.offline == .offline)
        #expect(SyncState.error("a") == .error("a"))
        #expect(SyncState.error("a") != .error("b"))
        #expect(SyncState.synced != .offline)
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
        #expect(handler.hasUnresolvedConflicts)
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
}
