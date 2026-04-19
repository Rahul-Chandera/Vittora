import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("CategoryMapper Tests")
struct CategoryMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let name = "Groceries"
        let icon = "cart.fill"
        let colorHex = "#FF3B30"
        let type = CategoryType.expense
        let isDefault = true
        let sortOrder = 3
        let parentID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDCategory(
            id: id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            isDefault: isDefault,
            sortOrder: sortOrder,
            parentID: parentID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = CategoryMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.name == name)
        #expect(entity.icon == icon)
        #expect(entity.colorHex == colorHex)
        #expect(entity.type == type)
        #expect(entity.isDefault == isDefault)
        #expect(entity.sortOrder == sortOrder)
        #expect(entity.parentID == parentID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil parentID correctly")
    func testToEntityMapsNilParentID() {
        let model = SDCategory(name: "Food", icon: "fork.knife", type: .expense)

        let entity = CategoryMapper.toEntity(model)

        #expect(entity.parentID == nil)
        #expect(entity.isDefault == false)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDCategory()
        let originalID = model.id
        let originalCreatedAt = model.createdAt
        let parentID = UUID()

        let entity = CategoryEntity(
            name: "Transport",
            icon: "car.fill",
            colorHex: "#34C759",
            type: .expense,
            isDefault: false,
            sortOrder: 5,
            parentID: parentID
        )

        CategoryMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.name == "Transport")
        #expect(model.icon == "car.fill")
        #expect(model.colorHex == "#34C759")
        #expect(model.type == .expense)
        #expect(model.isDefault == false)
        #expect(model.sortOrder == 5)
        #expect(model.parentID == parentID)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let parentID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDCategory(
            id: id,
            name: "Salary",
            icon: "dollarsign.circle.fill",
            colorHex: "#30D158",
            type: .income,
            isDefault: true,
            sortOrder: 1,
            parentID: parentID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = CategoryMapper.toEntity(model)
        CategoryMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.name == "Salary")
        #expect(model.icon == "dollarsign.circle.fill")
        #expect(model.colorHex == "#30D158")
        #expect(model.type == .income)
        #expect(model.isDefault == true)
        #expect(model.sortOrder == 1)
        #expect(model.parentID == parentID)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with both category types")
    func testToEntityWithBothCategoryTypes() {
        let types: [CategoryType] = [.expense, .income]

        for type in types {
            let model = SDCategory(name: "Test", icon: "star", type: type)
            let entity = CategoryMapper.toEntity(model)
            #expect(entity.type == type)
        }
    }

    @Test("updateModel preserves id and createdAt")
    func testUpdateModelPreservesIdAndCreatedAt() {
        let originalID = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_680_000_000)
        let model = SDCategory()
        model.id = originalID
        model.createdAt = originalCreatedAt

        let entity = CategoryEntity(name: "Updated", icon: "star.fill", type: .expense)

        CategoryMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }
}
