import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("CategoryEntity Tests")
struct CategoryEntityTests {
    @Test("Default initializer values")
    func testDefaultInitializerValues() {
        let entity = CategoryEntity(
            name: "Food",
            icon: "fork.knife"
        )

        #expect(entity.name == "Food")
        #expect(entity.icon == "fork.knife")
        #expect(entity.colorHex == "#007AFF")
        #expect(entity.type == .expense)
        #expect(entity.isDefault == false)
        #expect(entity.sortOrder == 0)
        #expect(entity.parentID == nil)
    }

    @Test("Custom initializer values")
    func testCustomInitializerValues() {
        let parentID = UUID()
        let entity = CategoryEntity(
            name: "Salary",
            icon: "dollarsign.circle.fill",
            colorHex: "#34C759",
            type: .income,
            isDefault: true,
            sortOrder: 5,
            parentID: parentID
        )

        #expect(entity.name == "Salary")
        #expect(entity.colorHex == "#34C759")
        #expect(entity.type == .income)
        #expect(entity.isDefault == true)
        #expect(entity.sortOrder == 5)
        #expect(entity.parentID == parentID)
    }

    @Test("CategoryType raw values")
    func testCategoryTypeRawValues() {
        #expect(CategoryType.expense.rawValue == "expense")
        #expect(CategoryType.income.rawValue == "income")
    }

    @Test("CategoryType CaseIterable contains all cases")
    func testCategoryTypeAllCases() {
        #expect(CategoryType.allCases.count == 2)
        #expect(CategoryType.allCases.contains(.expense))
        #expect(CategoryType.allCases.contains(.income))
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let id = UUID()
        let entity = CategoryEntity(id: id, name: "Test", icon: "tag.fill")
        #expect(entity.id == id)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let id = UUID()
        let entity1 = CategoryEntity(id: id, name: "Food", icon: "fork.knife", type: .expense)
        let entity2 = CategoryEntity(id: id, name: "Food", icon: "fork.knife", type: .expense)
        #expect(entity1 == entity2)
    }

    @Test("Hashable conformance")
    func testHashable() {
        let id = UUID()
        let entity1 = CategoryEntity(id: id, name: "Food", icon: "fork.knife")
        let entity2 = CategoryEntity(id: id, name: "Food", icon: "fork.knife")

        var set: Set<CategoryEntity> = [entity1]
        set.insert(entity2)
        #expect(set.count == 1)
    }
}
