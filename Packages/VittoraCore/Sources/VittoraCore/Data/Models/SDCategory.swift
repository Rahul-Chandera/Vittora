import Foundation
import SwiftData

@Model
public final class SDCategory {
    #Index<SDCategory>([\.typeRawValue], [\.parentID])

    public var id: UUID = UUID()
    public var name: String = ""
    public var icon: String = ""
    public var colorHex: String = "#007AFF"
    public var typeRawValue: String = CategoryType.expense.rawValue
    public var isDefault: Bool = false
    public var sortOrder: Int = 0
    public var parentID: UUID?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
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

    public var type: CategoryType {
        get { CategoryType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}
