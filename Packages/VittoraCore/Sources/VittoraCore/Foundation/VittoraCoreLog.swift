import Foundation
import OSLog

enum VittoraCoreLog {
    nonisolated static let security = Logger(subsystem: "com.vittora.app", category: "Security")
    nonisolated static let sync = Logger(subsystem: "com.vittora.app", category: "Sync")
}
