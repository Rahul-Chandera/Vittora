import Foundation
import SwiftData

@Model
final class SDSplitGroup {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// JSON-encoded [UUID] of member payee IDs
    var memberIDsJSON: String = "[]"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

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
        guard let data = try? JSONEncoder().encode(ids),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func decode(_ json: String) -> [UUID] {
        guard let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
        return ids
    }
}
