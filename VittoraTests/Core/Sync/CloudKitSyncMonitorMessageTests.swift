import CloudKit
import Foundation
import Testing
import VittoraCore

/// The sync banner must never surface raw CloudKit descriptions like
/// "CKErrorDomain error 2" — App Review screenshotted exactly that in the
/// 2026-07-16 Mac review. Every mapped message is plain language.
@Suite("CloudKitSyncMonitor friendly messages")
@MainActor
struct CloudKitSyncMonitorMessageTests {

    private func makeMonitor() throws -> CloudKitSyncMonitor {
        let suiteName = "com.vittora.test.\(UUID().uuidString)"
        let ud = try #require(UserDefaults(suiteName: suiteName))
        return CloudKitSyncMonitor(
            syncStatusService: SyncStatusService(isMonitoringEnabled: false, userDefaults: ud),
            conflictHandler: SyncConflictHandler(),
            notificationCenter: NotificationCenter()
        )
    }

    @Test("CKError codes map to plain language, never the raw domain string")
    func mapsKnownCodes() throws {
        let monitor = try makeMonitor()
        let cases: [(CKError.Code, String)] = [
            (.notAuthenticated, "Sign in to iCloud"),
            (.networkUnavailable, "back online"),
            (.networkFailure, "back online"),
            (.quotaExceeded, "storage is full"),
            (.partialFailure, "temporarily unavailable"),
            (.internalError, "temporarily unavailable"),
        ]
        for (code, expectedFragment) in cases {
            let message = monitor.friendlySyncMessage(for: CKError(code))
            #expect(message.contains(expectedFragment), "\(code) → \(message)")
            #expect(!message.contains("CKErrorDomain"))
        }
    }

    @Test("CKError nested under NSUnderlyingErrorKey is still mapped")
    func mapsWrappedError() throws {
        let monitor = try makeMonitor()
        let wrapped = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134400,
            userInfo: [NSUnderlyingErrorKey: CKError(.notAuthenticated)]
        )
        #expect(monitor.friendlySyncMessage(for: wrapped).contains("Sign in to iCloud"))
    }

    @Test("Non-CloudKit errors fall back to the generic reassurance")
    func nonCloudKitFallback() throws {
        let monitor = try makeMonitor()
        let message = monitor.friendlySyncMessage(
            for: NSError(domain: "SomeDomain", code: 42)
        )
        #expect(message.contains("Your data is safe on this device"))
    }

    @Test("syncDiagnosticCode returns the CloudKit code for a plain CKError")
    func diagnosticCodeForPlainCKError() throws {
        let monitor = try makeMonitor()
        let codes: [CKError.Code] = [
            .quotaExceeded,
            .notAuthenticated,
            .internalError,
            .partialFailure,
        ]
        for code in codes {
            #expect(
                monitor.syncDiagnosticCode(for: CKError(code)) == "CKError.\(code.rawValue)",
                "\(code) should fingerprint as CKError.\(code.rawValue)"
            )
        }
    }

    /// A real 1.7.1 support payload read only `SyncError(CKError.2)`:
    /// `partialFailure` is a wrapper, and the per-record reasons inside it —
    /// the part that tells a Production schema rejection from anything else —
    /// were discarded. Distinct inner codes are now appended, sorted.
    @Test("a partial failure reports the distinct per-record codes inside it")
    func diagnosticCodeUnwrapsPartialFailure() throws {
        let monitor = try makeMonitor()
        let recordA = CKRecord.ID(recordName: "a")
        let recordB = CKRecord.ID(recordName: "b")
        let recordC = CKRecord.ID(recordName: "c")
        let partial = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: [
                recordA: CKError(.serverRejectedRequest),
                recordB: CKError(.invalidArguments),
                recordC: CKError(.serverRejectedRequest),
            ]]
        )

        #expect(monitor.syncDiagnosticCode(for: partial) == "CKError.2(12,15)")
    }

    /// Descriptions can name the container or account; only codes may leave.
    /// A schema rejection's description names the record type and field, so
    /// it is the one most likely to be tempting to include.
    @Test("unwrapping never leaks a per-record description")
    func unwrappedCodeLeaksNoDescription() throws {
        let monitor = try makeMonitor()
        let rejected = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.serverRejectedRequest.rawValue,
            userInfo: [NSLocalizedDescriptionKey:
                "Cannot create or modify field 'CD_categorySuggestionRawValue' in record 'CD_SDTransaction' in production schema"]
        )
        let partial = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "a"): rejected]]
        )

        let code = monitor.syncDiagnosticCode(for: partial)
        #expect(code == "CKError.2(15)")
        #expect(!code.contains("CD_"))
        #expect(!code.contains("schema"))
    }

    @Test("syncDiagnosticCode unwraps CKError nested under NSUnderlyingErrorKey")
    func diagnosticCodeForWrappedCKError() throws {
        let monitor = try makeMonitor()
        let wrapped = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134400,
            userInfo: [NSUnderlyingErrorKey: CKError(.quotaExceeded)]
        )
        #expect(
            monitor.syncDiagnosticCode(for: wrapped) == "CKError.\(CKError.Code.quotaExceeded.rawValue)",
            "wrapped quotaExceeded should still fingerprint as CKError"
        )
    }

    @Test("syncDiagnosticCode falls back to domain.code and leaks no user-identifying detail")
    func diagnosticCodeForNonCloudKitError() throws {
        let monitor = try makeMonitor()
        let error = NSError(
            domain: "SomeDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "account rahul@example.com quota"]
        )
        let result = monitor.syncDiagnosticCode(for: error)
        #expect(result == "SomeDomain.42", "non-CKError should be domain.code only")
        #expect(!result.contains("rahul"), "diagnostic must not contain account local-part")
        #expect(!result.contains("@"), "diagnostic must not contain email @")
    }
}
