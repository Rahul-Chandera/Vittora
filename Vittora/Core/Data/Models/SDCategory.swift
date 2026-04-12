import Foundation
import SwiftData

@Model
final class SDCategory {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""
    var colorHex: String = "#007AFF"
    var typeRawValue: String = CategoryType.expense.rawValue
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var parentID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
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
        self.typeRawValue = type.rawValue
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: CategoryType {
        get { CategoryType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}
