import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M1.3.4. Every rule here exists because dropping it produces a tree deeper than one
/// level, or a cycle, and every consumer of `parentID` assumes neither.
@Suite("Category Hierarchy Tests")
struct CategoryHierarchyTests {

    private func category(
        _ name: String,
        type: CategoryType = .expense,
        parentID: UUID? = nil,
        sortOrder: Int = 0
    ) -> CategoryEntity {
        CategoryEntity(
            id: UUID(),
            name: name,
            icon: "tag.fill",
            colorHex: "#007AFF",
            type: type,
            isDefault: false,
            sortOrder: sortOrder,
            parentID: parentID,
            spendingBucket: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test("a new category may choose any root of the same type")
    func newCategorySeesRoots() {
        let groceries = category("Groceries")
        let transport = category("Transport")
        let all = [groceries, transport]

        let eligible = CategoryHierarchy.eligibleParents(for: nil, in: all, type: .expense)
        #expect(Set(eligible.map(\.id)) == Set([groceries.id, transport.id]))
    }

    @Test("income categories are never offered as parents for an expense")
    func typesDoNotMix() {
        let salary = category("Salary", type: .income)
        let groceries = category("Groceries")

        let eligible = CategoryHierarchy.eligibleParents(for: nil, in: [salary, groceries], type: .expense)
        #expect(eligible.map(\.id) == [groceries.id])
    }

    /// The rule that keeps the tree one level deep.
    @Test("a category that already has a parent is not offered as one")
    func childrenAreNotOfferedAsParents() {
        let groceries = category("Groceries")
        let veg = category("Vegetables", parentID: groceries.id)

        let eligible = CategoryHierarchy.eligibleParents(for: nil, in: [groceries, veg], type: .expense)
        #expect(eligible.map(\.id) == [groceries.id])
    }

    @Test("a category is never offered as its own parent")
    func selfIsNeverAParent() {
        let groceries = category("Groceries")
        let transport = category("Transport")

        let eligible = CategoryHierarchy.eligibleParents(
            for: groceries,
            in: [groceries, transport],
            type: .expense
        )
        #expect(eligible.map(\.id) == [transport.id])
    }

    /// The other way one level becomes two: a parent that is moved under someone else
    /// while still holding children.
    @Test("a category with children cannot be given a parent")
    func parentsWithChildrenCannotBecomeChildren() {
        let groceries = category("Groceries")
        let veg = category("Vegetables", parentID: groceries.id)
        let transport = category("Transport")

        let eligible = CategoryHierarchy.eligibleParents(
            for: groceries,
            in: [groceries, veg, transport],
            type: .expense
        )
        #expect(eligible.isEmpty)
        #expect(CategoryHierarchy.hasChildren(groceries, in: [groceries, veg]))
        #expect(CategoryHierarchy.hasChildren(transport, in: [groceries, veg, transport]) == false)
    }

    @Test("grouping nests children under their parent")
    func groupingNestsChildren() {
        let groceries = category("Groceries", sortOrder: 0)
        let veg = category("Vegetables", parentID: groceries.id)
        let fruit = category("Fruit", parentID: groceries.id)
        let transport = category("Transport", sortOrder: 1)

        let grouped = CategoryHierarchy.grouped([veg, groceries, transport, fruit])

        #expect(grouped.map(\.parent.id) == [groceries.id, transport.id])
        #expect(Set(grouped[0].children.map(\.id)) == Set([veg.id, fruit.id]))
        #expect(grouped[1].children.isEmpty)
    }

    /// CloudKit delivers records in whatever order it likes. A child whose parent has not
    /// arrived yet must still be visible, or the list reads as data loss.
    @Test("a child whose parent is missing is promoted to a root, not dropped")
    func orphanIsPromotedNotDropped() {
        let orphan = category("Vegetables", parentID: UUID())

        let grouped = CategoryHierarchy.grouped([orphan])
        #expect(grouped.map(\.parent.id) == [orphan.id])
    }

    @Test("a child pointing at a parent of the wrong type is promoted too")
    func mismatchedTypeChildIsPromoted() {
        let salary = category("Salary", type: .income)
        let odd = category("Vegetables", type: .expense, parentID: salary.id)

        let grouped = CategoryHierarchy.grouped([salary, odd])
        #expect(Set(grouped.map(\.parent.id)) == Set([salary.id, odd.id]))
    }

    @Test("an empty list groups to nothing rather than crashing")
    func emptyListIsEmpty() {
        #expect(CategoryHierarchy.grouped([]).isEmpty)
        #expect(CategoryHierarchy.eligibleParents(for: nil, in: [], type: .expense).isEmpty)
    }
}
