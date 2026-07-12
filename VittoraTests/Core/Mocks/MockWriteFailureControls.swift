import Foundation
import VittoraCore

/// Shared write-failure hooks for in-memory repository test doubles (Epic L2).
struct MockWriteFailureControls: Sendable {
    var failOnNextWriteCount: Int = 0
    var failForIDs: Set<UUID> = []
    var writeError: VittoraError = .unknown(String(localized: "Mock write failure"))

    mutating func checkWrite(entityID: UUID? = nil) throws {
        if failOnNextWriteCount > 0 {
            failOnNextWriteCount -= 1
            throw writeError
        }
        if let entityID, failForIDs.contains(entityID) {
            throw writeError
        }
    }

    mutating func reset() {
        failOnNextWriteCount = 0
        failForIDs.removeAll()
    }
}
