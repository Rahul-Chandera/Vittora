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
        let expenseCategories: [(name: String, icon: String, color: String)] = [
            (String(localized: "Groceries"), "cart.fill", "#FF6B6B"),
            (String(localized: "Dining"), "fork.knife", "#FFA94D"),
            (String(localized: "Transport"), "car.fill", "#FFD93D"),
            (String(localized: "Entertainment"), "film.fill", "#6BCB77"),
            (String(localized: "Shopping"), "bag.fill", "#4D96FF"),
            (String(localized: "Health"), "heart.fill", "#FF1493"),
            (String(localized: "Education"), "book.fill", "#9D4EDD"),
            (String(localized: "Utilities"), "bolt.fill", "#FFB703"),
            (String(localized: "Rent"), "house.fill", "#FB5607"),
            (String(localized: "EMI"), "indianrupeesign.circle.fill", "#5A189A"),
            (String(localized: "Insurance"), "shield.fill", "#3A0CA3"),
            (String(localized: "Personal Care"), "figure.walk", "#E76F51"),
            (String(localized: "Gifts"), "gift.fill", "#F4A261"),
            (String(localized: "Travel"), "airplane", "#2A9D8F"),
            (String(localized: "Subscriptions"), "repeat", "#264653"),
            (String(localized: "Phone"), "phone.fill", "#E9C46A"),
            (String(localized: "Internet"), "wifi", "#D4A574"),
            (String(localized: "Clothing"), "tshirt.fill", "#B8860B"),
            (String(localized: "Pets"), "pawprint.fill", "#D2691E"),
            (String(localized: "Charity"), "heart.circle.fill", "#CD5C5C"),
            (String(localized: "Other"), "ellipsis.circle.fill", "#808080")
        ]

        for (index, category) in expenseCategories.enumerated() {
            let sdCategory = SDCategory(
                id: UUID(),
                name: category.name,
                icon: category.icon,
                colorHex: category.color,
                type: .expense,
                isDefault: true,
                sortOrder: index
            )
            modelContext.insert(sdCategory)
        }

        try modelContext.save()
    }

    private func seedIncomeCategories() async throws {
        let incomeCategories: [(name: String, icon: String, color: String)] = [
            (String(localized: "Salary"), "briefcase.fill", "#06D6A0"),
            (String(localized: "Freelance"), "laptopcomputer", "#118AB2"),
            (String(localized: "Investments"), "chart.line.uptrend.xyaxis", "#073B4C"),
            (String(localized: "Gifts Received"), "gift.fill", "#EF476F"),
            (String(localized: "Other Income"), "dollarsign.circle.fill", "#FFD60A")
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
