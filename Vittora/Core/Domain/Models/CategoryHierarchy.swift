import Foundation
import VittoraCore

/// One level of category nesting (M1.3.4).
///
/// The `parentID` column and the form's `selectedParentID` have existed since the schema
/// gained them, but nothing ever bound them, so the rules that keep a hierarchy one level
/// deep had nowhere to live. They live here, as pure functions over a category list, so
/// they are testable without a store and cannot drift between the picker and the list.
enum CategoryHierarchy {

    /// Categories a user may pick as the parent of `category`.
    ///
    /// Four rules, each of which produces a broken tree if dropped:
    /// - Same type only. An expense category under an income one would appear in pickers
    ///   and reports that filter by type, with a parent that is invisible there.
    /// - The candidate must be a root. Allowing a child as a parent is how one level
    ///   becomes two, and every consumer here assumes one.
    /// - Never itself. A self-parent is a cycle that no traversal survives.
    /// - Never a category that already has children. Otherwise a parent becomes a child
    ///   while still holding children, which is two levels by another route.
    ///
    /// Passing `nil` for `category` is the new-category case: everything eligible is a
    /// candidate because nothing can point at a record that does not exist yet.
    nonisolated static func eligibleParents(
        for category: CategoryEntity?,
        in categories: [CategoryEntity],
        type: CategoryType
    ) -> [CategoryEntity] {
        let parentsInUse = Set(categories.compactMap(\.parentID))
        return categories
            .filter { candidate in
                guard candidate.type == type else { return false }
                guard candidate.parentID == nil else { return false }
                guard candidate.id != category?.id else { return false }
                if let category, parentsInUse.contains(category.id) { return false }
                return true
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// True when this category has children, so it cannot itself become one.
    nonisolated static func hasChildren(_ category: CategoryEntity, in categories: [CategoryEntity]) -> Bool {
        categories.contains { $0.parentID == category.id }
    }

    nonisolated static func children(of parent: CategoryEntity, in categories: [CategoryEntity]) -> [CategoryEntity] {
        categories
            .filter { $0.parentID == parent.id }
            .sorted { $0.sortOrder == $1.sortOrder
                ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                : $0.sortOrder < $1.sortOrder }
    }

    /// Roots with their children attached, for a grouped list.
    ///
    /// A child whose parent is missing or is the wrong type is promoted to a root rather
    /// than dropped. Data can arrive from CloudKit in any order, and a category that
    /// vanishes from the list because its parent has not synced yet reads as data loss.
    nonisolated static func grouped(_ categories: [CategoryEntity]) -> [(parent: CategoryEntity, children: [CategoryEntity])] {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let roots = categories.filter { category in
            guard let parentID = category.parentID else { return true }
            guard let parent = byID[parentID] else { return true }
            return parent.type != category.type
        }
        return roots
            .sorted { $0.sortOrder == $1.sortOrder
                ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                : $0.sortOrder < $1.sortOrder }
            .map { (parent: $0, children: children(of: $0, in: categories)) }
    }
}
