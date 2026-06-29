import Foundation

enum CategoryType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income
}

struct CategoryEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var name: String
    nonisolated var icon: String
    nonisolated var colorHex: String
    nonisolated var type: CategoryType
    nonisolated var isDefault: Bool
    nonisolated var sortOrder: Int
    nonisolated var parentID: UUID?
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String = "#007AFF",
        type: CategoryType = .expense,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        parentID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Equatable & Hashable (identity-based)

    static func == (lhs: CategoryEntity, rhs: CategoryEntity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
