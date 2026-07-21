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
        let userDefaults = UserDefaults.standard
        guard !userDefaults.bool(forKey: seededKey) else {
            return
        }

        try await seedExpenseCategories()
        try await seedIncomeCategories()

        userDefaults.set(true, forKey: seededKey)
    }

    public func reseedDefaultCategories() async throws {
        try await seedExpenseCategories()
        try await seedIncomeCategories()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    private func seedExpenseCategories() async throws {
        let expenseCategories: [(name: String, icon: String, color: String, bucket: SpendingBucket)] = [
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

        for (index, category) in expenseCategories.enumerated() {
            let sdCategory = SDCategory(
                id: UUID(),
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                type: .expense,
                isDefault: true,
                sortOrder: index,
                spendingBucket: category.bucket
            )
            modelContext.insert(sdCategory)
        }

        try modelContext.save()
    }

    private func seedIncomeCategories() async throws {
        let incomeCategories: [(name: String, icon: String, color: String)] = [
            ("Salary", "briefcase.fill", "#06D6A0"),
            ("Freelance", "laptopcomputer", "#118AB2"),
            ("Investments", "chart.line.uptrend.xyaxis", "#073B4C"),
            ("Gifts Received", "gift.fill", "#EF476F"),
            ("Other Income", "dollarsign.circle.fill", "#FFD60A")
        ]

        for (index, category) in incomeCategories.enumerated() {
            let sdCategory = SDCategory(
                id: UUID(),
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                type: .income,
                isDefault: true,
                sortOrder: index
            )
            modelContext.insert(sdCategory)
        }

        try modelContext.save()
    }
}
