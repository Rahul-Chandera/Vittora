import Foundation
import OSLog
import SwiftData

@Model
final class SDSplitGroup {
    #Index<SDSplitGroup>([\.name], [\.createdAt])

    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// JSON-encoded [UUID] of member payee IDs
    var memberIDsJSON: String = "[]"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    init() {}

    init(
        id: UUID = UUID(),
        name: String,
        memberIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.memberIDsJSON = SDSplitGroup.encode(memberIDs)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var memberIDs: [UUID] {
        get { SDSplitGroup.decode(memberIDsJSON) }
        set { memberIDsJSON = SDSplitGroup.encode(newValue) }
    }

    private static func encode(_ ids: [UUID]) -> String {
        do {
            let data = try JSONEncoder().encode(ids)
            guard let str = String(data: data, encoding: .utf8) else {
                logger.error("Failed to encode split group member IDs as UTF-8.")
                return "[]"
            }
            return str
        } catch {
            logger.error("Failed to encode split group member IDs: \(error.localizedDescription, privacy: .public)")
            return "[]"
        }
    }

    private static func decode(_ json: String) -> [UUID] {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to decode split group member IDs JSON as UTF-8.")
            return []
        }

        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            logger.error("Failed to decode split group member IDs: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
