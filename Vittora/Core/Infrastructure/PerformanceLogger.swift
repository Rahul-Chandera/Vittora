import os.signpost
import Foundation

// MARK: - Performance Logger

/// Wraps `os_signpost` for structured performance instrumentation.
/// Instruments appear in Xcode Instruments under the "Points of Interest" lane.
enum PerformanceLogger {

    // MARK: - Log Handles

    static let appLog     = OSLog(subsystem: "com.vittora.app", category: "App")
    static let dataLog    = OSLog(subsystem: "com.vittora.app", category: "Data")
    static let uiLog      = OSLog(subsystem: "com.vittora.app", category: "UI")
    static let syncLog    = OSLog(subsystem: "com.vittora.app", category: "Sync")
    static let exportLog  = OSLog(subsystem: "com.vittora.app", category: "Export")

    // MARK: - Convenience Wrappers

    /// Begin an interval signpost. Call `end(_:name:)` with the returned value to close it.
    @discardableResult
    static func begin(_ log: OSLog, name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    /// End a previously begun interval signpost.
    static func end(_ log: OSLog, name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    /// Emit a point-in-time event.
    static func event(_ log: OSLog, name: StaticString, message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}@", message)
    }

    // MARK: - Named Operations

    /// Measure an async closure, logging begin/end signposts.
    static func measure<T>(
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
        static func didFinishLaunching() {
            event(appLog, name: "AppDidLaunch", message: "App finished launching")
        }
        static func sceneDidBecomeActive() {
            event(appLog, name: "SceneActive", message: "Scene became active")
        }
    }

    struct Dashboard {
        static func beginLoad() -> OSSignpostID { begin(uiLog, name: "DashboardLoad") }
        static func endLoad(id: OSSignpostID) { end(uiLog, name: "DashboardLoad", id: id) }
    }

    struct Transactions {
        static func beginFetch() -> OSSignpostID { begin(dataLog, name: "TransactionFetch") }
        static func endFetch(id: OSSignpostID) { end(dataLog, name: "TransactionFetch", id: id) }
    }

    struct Export {
        static func beginCSV() -> OSSignpostID { begin(exportLog, name: "CSVExport") }
        static func endCSV(id: OSSignpostID) { end(exportLog, name: "CSVExport", id: id) }
    }

    struct Sync {
        static func beginSync() -> OSSignpostID { begin(syncLog, name: "CloudKitSync") }
        static func endSync(id: OSSignpostID) { end(syncLog, name: "CloudKitSync", id: id) }
        static func conflict() { event(syncLog, name: "SyncConflict") }
    }
}
