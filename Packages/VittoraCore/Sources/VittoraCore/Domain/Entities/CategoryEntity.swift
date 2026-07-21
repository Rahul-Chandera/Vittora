import Foundation

public enum CategoryType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income
}

public enum SpendingBucket: String, Sendable, Hashable, CaseIterable, Codable {
    case needs
    case wants
    case savings

    public var displayName: String {
        switch self {
        case .needs: String(localized: "Needs")
        case .wants: String(localized: "Wants")
        case .savings: String(localized: "Savings")
        }
    }

    public nonisolated static func defaultBucket(
        categoryName: String,
        type: CategoryType
    ) -> SpendingBucket {
        guard type == .expense else { return .wants }
        let needs = [
            "Groceries", "Transport", "Health", "Education", "Utilities", "Rent",
            "EMI", "Insurance", "Personal Care", "Phone", "Internet", "Clothing", "Pets",
        ]
        return needs.contains(categoryName) ? .needs : .wants
    }
}

public struct CategoryEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var icon: String
    public nonisolated var colorHex: String
    public nonisolated var type: CategoryType
    public nonisolated var isDefault: Bool
    public nonisolated var sortOrder: Int
    public nonisolated var parentID: UUID?
    public nonisolated var spendingBucket: SpendingBucket?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String = "#007AFF",
        type: CategoryType = .expense,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        parentID: UUID? = nil,
        spendingBucket: SpendingBucket? = nil,
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
        self.spendingBucket = spendingBucket
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Equatable & Hashable (identity-based)

    public static func == (lhs: CategoryEntity, rhs: CategoryEntity) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
