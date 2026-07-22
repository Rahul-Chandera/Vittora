import Foundation
import SwiftData
import Testing
import VittoraCore

@MainActor
@Suite("DefaultDataSeeder Tests", .serialized)
struct DefaultDataSeederTests {
    private let seededKey = "com.vittora.defaultDataSeeded"

    @Test("reinstall state does not duplicate defaults and preserves stable IDs")
    func reinstallStateIsIdempotent() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let seeder = DefaultDataSeeder(modelContainer: container)

        try await seeder.seedDefaultCategoriesIfNeeded()
        let firstDefaults = try defaultCategories(in: container.mainContext)
        let firstGroceriesID = try #require(
            firstDefaults.first { $0.name == "Groceries" && $0.type == .expense }?.id
        )

        UserDefaults.standard.removeObject(forKey: seededKey)
        try await seeder.seedDefaultCategoriesIfNeeded()
        let secondDefaults = try defaultCategories(in: container.mainContext)
        let secondGroceriesID = try #require(
            secondDefaults.first { $0.name == "Groceries" && $0.type == .expense }?.id
        )

        #expect(firstDefaults.count == 26)
        #expect(secondDefaults.count == firstDefaults.count)
        #expect(secondGroceriesID == firstGroceriesID)
    }

    @Test("partial defaults add only missing records and leave custom categories untouched")
    func partialDefaultsAreCompleted() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let context = container.mainContext
        let legacyDefault = SDCategory(
            id: UUID(),
            name: "Groceries",
            icon: "cart.fill",
            type: .expense,
            isDefault: true
        )
        let customID = UUID()
        let custom = SDCategory(
            id: customID,
            name: "Groceries",
            icon: "star.fill",
            type: .expense,
            isDefault: false
        )
        context.insert(legacyDefault)
        context.insert(custom)
        try context.save()

        try await DefaultDataSeeder(modelContainer: container).seedDefaultCategoriesIfNeeded()

        let defaults = try defaultCategories(in: context)
        let allCategories = try context.fetch(FetchDescriptor<SDCategory>())
        #expect(defaults.count == 26)
        #expect(defaults.count { $0.name == "Groceries" && $0.type == .expense } == 1)
        #expect(defaults.contains { $0.name == "Salary" && $0.type == .income })
        #expect(allCategories.contains { $0.id == customID && !$0.isDefault })
    }

    @Test("deduplication re-points every category reference before deletion")
    func deduplicationPreservesReferences() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let context = container.mainContext
        let survivorCreatedAt = Date(timeIntervalSince1970: 1)
        let duplicateID = UUID()
        context.insert(SDCategory(
            id: UUID(),
            name: "Groceries",
            icon: "cart.fill",
            type: .expense,
            isDefault: true,
            createdAt: survivorCreatedAt
        ))
        context.insert(SDCategory(
            id: duplicateID,
            name: "Groceries",
            icon: "cart.fill",
            type: .expense,
            isDefault: true,
            createdAt: Date(timeIntervalSince1970: 2)
        ))
        let transaction = SDTransaction(amount: 10, categoryID: duplicateID)
        let budget = SDBudget(amount: 100, categoryID: duplicateID)
        let rule = SDRecurringRule(
            frequency: .monthly,
            nextDate: .now,
            templateAmount: 5,
            templateCategoryID: duplicateID
        )
        context.insert(transaction)
        context.insert(budget)
        context.insert(rule)
        try context.save()

        try await DefaultDataSeeder(modelContainer: container).seedDefaultCategoriesIfNeeded()

        let verificationContext = ModelContext(container)
        let groceries = try defaultCategories(in: verificationContext)
            .filter { $0.name == "Groceries" && $0.type == .expense }
        let survivor = try #require(groceries.first)
        let persistedTransaction = try #require(
            verificationContext.fetch(FetchDescriptor<SDTransaction>()).first
        )
        let persistedBudget = try #require(
            verificationContext.fetch(FetchDescriptor<SDBudget>()).first
        )
        let persistedRule = try #require(
            verificationContext.fetch(FetchDescriptor<SDRecurringRule>()).first
        )
        #expect(groceries.count == 1)
        #expect(survivor.createdAt == survivorCreatedAt)
        #expect(persistedTransaction.categoryID == survivor.id)
        #expect(persistedTransaction.categoryID != duplicateID)
        #expect(persistedBudget.categoryID == survivor.id)
        #expect(persistedRule.templateCategoryID == survivor.id)
    }

    @Test("factory reset reseed restores defaults")
    func factoryResetReseedRestoresDefaults() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let context = container.mainContext
        let seeder = DefaultDataSeeder(modelContainer: container)

        try await seeder.reseedDefaultCategories()
        for category in try defaultCategories(in: context) {
            context.delete(category)
        }
        try context.save()

        try await seeder.reseedDefaultCategories()

        #expect(try defaultCategories(in: context).count == 26)
    }

    private func defaultCategories(in context: ModelContext) throws -> [SDCategory] {
        try context.fetch(FetchDescriptor<SDCategory>()).filter(\.isDefault)
    }
}
