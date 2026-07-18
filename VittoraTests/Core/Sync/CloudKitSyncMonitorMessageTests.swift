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
}
