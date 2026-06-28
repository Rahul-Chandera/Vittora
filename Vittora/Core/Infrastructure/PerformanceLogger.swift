import os.signpost
import Foundation

// MARK: - Performance Logger

/// Wraps `os_signpost` for structured performance instrumentation.
/// Instruments appear in Xcode Instruments under the "Points of Interest" lane.
enum PerformanceLogger {

    // MARK: - Log Handles

    nonisolated(unsafe) static let appLog     = OSLog(subsystem: "com.vittora.app", category: "App")
    nonisolated(unsafe) static let dataLog    = OSLog(subsystem: "com.vittora.app", category: "Data")
    nonisolated(unsafe) static let uiLog      = OSLog(subsystem: "com.vittora.app", category: "UI")
    nonisolated(unsafe) static let syncLog    = OSLog(subsystem: "com.vittora.app", category: "Sync")
    nonisolated(unsafe) static let exportLog  = OSLog(subsystem: "com.vittora.app", category: "Export")

    // MARK: - Convenience Wrappers

    /// Begin an interval signpost. Call `end(_:name:)` with the returned value to close it.
    @discardableResult
    nonisolated static func begin(_ log: OSLog, name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    /// End a previously begun interval signpost.
    nonisolated static func end(_ log: OSLog, name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    /// Emit a point-in-time event.
    nonisolated static func event(_ log: OSLog, name: StaticString, message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}@", message)
    }

    // MARK: - Named Operations

    /// Measure an async closure, logging begin/end signposts.
    nonisolated static func measure<T>(
        _ log: OSLog,
        name: StaticString,
        operation: () async throws -> T
    ) async rethrows -> T {
        let id = begin(log, name: name)
        defer { end(log, name: name, id: id) }
        return try await operation()
    }

    // MARK: - Predefined Signpost Points

    struct App {
        nonisolated static func didFinishLaunching() {
            event(appLog, name: "AppDidLaunch", message: "App finished launching")
        }
        nonisolated static func sceneDidBecomeActive() {
            event(appLog, name: "SceneActive", message: "Scene became active")
        }
    }

    struct Dashboard {
        nonisolated static func beginLoad() -> OSSignpostID { begin(uiLog, name: "DashboardLoad") }
        nonisolated static func endLoad(id: OSSignpostID) { end(uiLog, name: "DashboardLoad", id: id) }
    }

    struct Transactions {
        nonisolated static func beginFetch() -> OSSignpostID { begin(dataLog, name: "TransactionFetch") }
        nonisolated static func endFetch(id: OSSignpostID) { end(dataLog, name: "TransactionFetch", id: id) }
    }

    struct Export {
        nonisolated static func beginCSV() -> OSSignpostID { begin(exportLog, name: "CSVExport") }
        nonisolated static func endCSV(id: OSSignpostID) { end(exportLog, name: "CSVExport", id: id) }
    }

    struct Sync {
        nonisolated static func beginSync() -> OSSignpostID { begin(syncLog, name: "CloudKitSync") }
        nonisolated static func endSync(id: OSSignpostID) { end(syncLog, name: "CloudKitSync", id: id) }
        nonisolated static func conflict() { event(syncLog, name: "SyncConflict") }
    }

    nonisolated(unsafe) static let securityLog = OSLog(subsystem: "com.vittora.app", category: "Security")

    struct Security {
        nonisolated static func authFailed(consecutiveCount: Int) {
            event(securityLog, name: "AuthFailed", message: "consecutive=\(consecutiveCount)")
        }
        nonisolated static func cooldownStarted(seconds: Int) {
            event(securityLog, name: "CooldownStarted", message: "duration=\(seconds)s")
        }
        nonisolated static func cooldownBlocked(remainingSeconds: Int) {
            event(securityLog, name: "CooldownBlocked", message: "remaining=\(remainingSeconds)s")
        }

        nonisolated static func auditWriteFailed(_ message: String) {
            event(securityLog, name: "AuditWriteFailed", message: message)
        }
        nonisolated static func auditReadFailed(_ message: String) {
            event(securityLog, name: "AuditReadFailed", message: message)
        }
        nonisolated static func auditDirectorySetupFailed(_ message: String) {
            event(securityLog, name: "AuditDirSetupFailed", message: message)
        }
        nonisolated static func auditDecodeFailed(_ message: String) {
            event(securityLog, name: "AuditDecodeFailed", message: message)
        }
        nonisolated static func auditFileProtectionUpdateFailed(_ message: String) {
            event(securityLog, name: "AuditFileProtectionUpdateFailed", message: message)
        }
        nonisolated static func auditFileHandleCloseFailed(_ message: String) {
            event(securityLog, name: "AuditFileHandleCloseFailed", message: message)
        }
        nonisolated static func platformFailure(_ message: String) {
            event(securityLog, name: "PlatformSecurityFailure", message: message)
        }
    }
}
