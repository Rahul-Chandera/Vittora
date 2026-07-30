import CryptoKit
import Foundation
import SwiftData

public protocol DataSeederProtocol: Sendable {
    func seedDefaultCategoriesIfNeeded() async throws
    /// Force re-seeds the default expense and income categories regardless of the
    /// "already seeded" gate. Intended for use after a factory reset, where all
    /// existing categories have just been deleted and we want to restore the
    /// out-of-the-box defaults so the app remains usable on next launch.
    func reseedDefaultCategories() async throws
}

@ModelActor
public actor DefaultDataSeeder: DataSeederProtocol {
    private let seededKey = "com.vittora.defaultDataSeeded"

    public func seedDefaultCategoriesIfNeeded() async throws {
        try reconcileDefaultCategories()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    public func reseedDefaultCategories() async throws {
        try reconcileDefaultCategories()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    private struct DefaultCategory: Sendable {
        let name: String
        let icon: String
        let color: String
        let type: CategoryType
        let sortOrder: Int
        let spendingBucket: SpendingBucket?

        var id: UUID {
            let canonicalIdentity = "com.vittora.default-category.v1|\(type.rawValue)|\(name)"
            var bytes = Array(SHA256.hash(data: Data(canonicalIdentity.utf8)).prefix(16))
            bytes[6] = (bytes[6] & 0x0F) | 0x80
            bytes[8] = (bytes[8] & 0x3F) | 0x80
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }

    private static let defaultCategories: [DefaultCategory] = {
        let expenses: [(String, String, String, SpendingBucket)] = [
            ("Groceries", "cart.fill", "#FF6B6B", .needs),
            ("Dining", "fork.knife", "#FFA94D", .wants),
            ("Transport", "car.fill", "#FFD93D", .needs),
            ("Entertainment", "film.fill", "#6BCB77", .wants),
            ("Shopping", "bag.fill", "#4D96FF", .wants),
            ("Health", "heart.fill", "#FF1493", .needs),
            ("Education", "book.fill", "#9D4EDD", .needs),
            ("Utilities", "bolt.fill", "#FFB703", .needs),
            ("Rent", "house.fill", "#FB5607", .needs),
            ("EMI", "indianrupeesign.circle.fill", "#5A189A", .needs),
            ("Insurance", "shield.fill", "#3A0CA3", .needs),
            ("Personal Care", "figure.walk", "#E76F51", .needs),
            ("Gifts", "gift.fill", "#F4A261", .wants),
            ("Travel", "airplane", "#2A9D8F", .wants),
            ("Subscriptions", "repeat", "#264653", .wants),
            ("Phone", "phone.fill", "#E9C46A", .needs),
            ("Internet", "wifi", "#D4A574", .needs),
            ("Clothing", "tshirt.fill", "#B8860B", .needs),
            ("Pets", "pawprint.fill", "#D2691E", .needs),
            ("Charity", "heart.circle.fill", "#CD5C5C", .wants),
            ("Other", "ellipsis.circle.fill", "#808080", .wants)
        ]
        let incomes: [(String, String, String)] = [
            ("Salary", "briefcase.fill", "#06D6A0"),
            ("Freelance", "laptopcomputer", "#118AB2"),
            ("Investments", "chart.line.uptrend.xyaxis", "#073B4C"),
            ("Gifts Received", "gift.fill", "#EF476F"),
            ("Other Income", "dollarsign.circle.fill", "#FFD60A")
        ]
        return expenses.enumerated().map { index, category in
            DefaultCategory(
                name: category.0,
                icon: category.1,
                color: category.2,
                type: .expense,
                sortOrder: index,
                spendingBucket: category.3
            )
        } + incomes.enumerated().map { index, category in
            DefaultCategory(
                name: category.0,
                icon: category.1,
                color: category.2,
                type: .income,
                sortOrder: index,
                spendingBucket: nil
            )
        }
    }()

    private func reconcileDefaultCategories() throws {
        let existingDefaults = try modelContext.fetch(
            FetchDescriptor<SDCategory>(predicate: #Predicate { $0.isDefault })
        )
        var replacementIDs: [UUID: UUID] = [:]
        var duplicatesToDelete: [SDCategory] = []

        for definition in Self.defaultCategories {
            let matches = existingDefaults
                .filter { $0.name == definition.name && $0.type == definition.type }
                .sorted {
                    $0.createdAt == $1.createdAt
                        ? $0.id.uuidString < $1.id.uuidString
                        : $0.createdAt < $1.createdAt
                }

            guard let survivor = matches.first else {
                modelContext.insert(SDCategory(
                    id: definition.id,
                    name: definition.name,
                    icon: definition.icon,
                    colorHex: definition.color,
                    type: definition.type,
                    isDefault: true,
                    sortOrder: definition.sortOrder,
                    spendingBucket: definition.spendingBucket
                ))
                continue
            }

            for oldID in matches.map(\.id) where oldID != definition.id {
                replacementIDs[oldID] = definition.id
            }
            if survivor.id != definition.id {
                survivor.id = definition.id
                survivor.updatedAt = .now
            }
            duplicatesToDelete.append(contentsOf: matches.dropFirst())
        }

        if !replacementIDs.isEmpty {
            try repointCategoryReferences(using: replacementIDs)
        }
        for duplicate in duplicatesToDelete {
            modelContext.delete(duplicate)
        }
        try modelContext.save()
    }

    private func repointCategoryReferences(using replacementIDs: [UUID: UUID]) throws {
        let now = Date.now
        for transaction in try modelContext.fetch(FetchDescriptor<SDTransaction>()) {
            if let categoryID = transaction.categoryID,
               let survivorID = replacementIDs[categoryID] {
                transaction.categoryID = survivorID
                transaction.updatedAt = now
            }
        }
        for budget in try modelContext.fetch(FetchDescriptor<SDBudget>()) {
            if let categoryID = budget.categoryID,
               let survivorID = replacementIDs[categoryID] {
                budget.categoryID = survivorID
                budget.updatedAt = now
            }
        }
        for rule in try modelContext.fetch(FetchDescriptor<SDRecurringRule>()) {
            if let categoryID = rule.templateCategoryID,
               let survivorID = replacementIDs[categoryID] {
                rule.templateCategoryID = survivorID
                rule.updatedAt = now
            }
        }
    }
}
