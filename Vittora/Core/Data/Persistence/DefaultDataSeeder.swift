import Foundation
import SwiftData

protocol DataSeederProtocol: Sendable {
    func seedDefaultCategoriesIfNeeded() async throws
}

@ModelActor
actor DefaultDataSeeder: DataSeederProtocol {
    private let seededKey = "com.vittora.defaultDataSeeded"

    func seedDefaultCategoriesIfNeeded() async throws {
        let userDefaults = UserDefaults.standard
        guard !userDefaults.bool(forKey: seededKey) else {
            return
        }

        try await seedExpenseCategories()
        try await seedIncomeCategories()

        userDefaults.set(true, forKey: seededKey)
    }

    private func seedExpenseCategories() async throws {
        let expenseCategories: [(name: String, icon: String, color: String)] = [
            ("Groceries", "cart.fill", "#FF6B6B"),
            ("Dining", "fork.knife", "#FFA94D"),
            ("Transport", "car.fill", "#FFD93D"),
            ("Entertainment", "film.fill", "#6BCB77"),
            ("Shopping", "bag.fill", "#4D96FF"),
            ("Health", "heart.fill", "#FF1493"),
            ("Education", "book.fill", "#9D4EDD"),
            ("Utilities", "bolt.fill", "#FFB703"),
            ("Rent", "house.fill", "#FB5607"),
            ("Insurance", "shield.fill", "#3A0CA3"),
            ("Personal Care", "figure.walk", "#E76F51"),
            ("Gifts", "gift.fill", "#F4A261"),
            ("Travel", "airplane", "#2A9D8F"),
            ("Subscriptions", "repeat", "#264653"),
            ("Phone", "phone.fill", "#E9C46A"),
            ("Internet", "wifi", "#D4A574"),
            ("Clothing", "tshirt.fill", "#B8860B"),
            ("Pets", "pawprint.fill", "#D2691E"),
            ("Charity", "heart.circle.fill", "#CD5C5C"),
            ("Other", "ellipsis.circle.fill", "#808080")
        ]

        for (index, category) in expenseCategories.enumerated() {
            let sdCategory = SDCategory(
                id: UUID(),
                name: String(localized: category.name),
                icon: category.icon,
                colorHex: category.color,
                typeRawValue: CategoryType.expense.rawValue,
                isDefault: true,
                sortOrder: index,
                createdAt: .now,
                updatedAt: .now
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
                name: String(localized: category.name),
                icon: category.icon,
                colorHex: category.color,
                typeRawValue: CategoryType.income.rawValue,
                isDefault: true,
                sortOrder: index,
                createdAt: .now,
                updatedAt: .now
            )
            modelContext.insert(sdCategory)
        }

        try modelContext.save()
    }
}
