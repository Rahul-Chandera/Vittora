import Foundation

struct CategorizationRule: Codable, Sendable, Identifiable, Equatable {
    var id: UUID
    var keyword: String
    var categoryID: UUID
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        keyword: String,
        categoryID: UUID,
        isEnabled: Bool = true,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.keyword = keyword
        self.categoryID = categoryID
        self.isEnabled = isEnabled
        self.createdAt = createdAt ?? Date()
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
