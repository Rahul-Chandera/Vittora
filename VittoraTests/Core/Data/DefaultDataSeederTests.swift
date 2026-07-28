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

    @Test("locale changes preserve canonical defaults and IDs while updating display names")
    func localeChangePreservesDefaultsAndUpdatesDisplayNames() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let seeder = DefaultDataSeeder(modelContainer: container)

        try await seeder.seedDefaultCategoriesIfNeeded()
        let firstDefaults = try defaultCategories(in: container.mainContext)
        let firstIDs = Dictionary(uniqueKeysWithValues: firstDefaults.map {
            ("\($0.type.rawValue)|\($0.name)", $0.id)
        })
        let firstGroceries = try #require(
            firstDefaults.first { $0.name == "Groceries" && $0.type == .expense }
        )
        let firstEntity = CategoryMapper.toEntity(firstGroceries)

        try await seeder.seedDefaultCategoriesIfNeeded()
        let secondDefaults = try defaultCategories(in: container.mainContext)
        let secondIDs = Dictionary(uniqueKeysWithValues: secondDefaults.map {
            ("\($0.type.rawValue)|\($0.name)", $0.id)
        })
        let secondGroceries = try #require(
            secondDefaults.first { $0.name == "Groceries" && $0.type == .expense }
        )
        let secondEntity = CategoryMapper.toEntity(secondGroceries)
        let appBundle = try #require(
            Bundle.allBundles.first { $0.bundleIdentifier == "com.enerjiktech.vittora" }
        )

        #expect(firstDefaults.count == 26)
        #expect(secondDefaults.count == 26)
        #expect(secondIDs == firstIDs)
        #expect(firstEntity.displayName(locale: Locale(identifier: "en"), bundle: appBundle) == "Groceries")
        #expect(secondEntity.displayName(locale: Locale(identifier: "hi"), bundle: appBundle) == "किराना")
        #expect(secondEntity.displayName(locale: Locale(identifier: "es"), bundle: appBundle) == "Comestibles")
        #expect(secondGroceries.name == "Groceries")
    }

    @Test("locale switch en→es preserves defaults without duplicates")
    func localeSwitchToSpanishPreservesDefaultsWithoutDuplicates() async throws {
        UserDefaults.standard.removeObject(forKey: seededKey)
        defer { UserDefaults.standard.removeObject(forKey: seededKey) }
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let seeder = DefaultDataSeeder(modelContainer: container)

        try await seeder.seedDefaultCategoriesIfNeeded()
        let englishDefaults = try defaultCategories(in: container.mainContext)
        let englishIDs = Dictionary(uniqueKeysWithValues: englishDefaults.map {
            ("\($0.type.rawValue)|\($0.name)", $0.id)
        })
        let englishGroceries = try #require(
            englishDefaults.first { $0.name == "Groceries" && $0.type == .expense }
        )
        let englishEntity = CategoryMapper.toEntity(englishGroceries)

        UserDefaults.standard.removeObject(forKey: seededKey)
        try await seeder.seedDefaultCategoriesIfNeeded()
        let spanishDefaults = try defaultCategories(in: container.mainContext)
        let spanishIDs = Dictionary(uniqueKeysWithValues: spanishDefaults.map {
            ("\($0.type.rawValue)|\($0.name)", $0.id)
        })
        let spanishGroceries = try #require(
            spanishDefaults.first { $0.name == "Groceries" && $0.type == .expense }
        )
        let spanishEntity = CategoryMapper.toEntity(spanishGroceries)
        let customGym = CategoryEntity(name: "Gym", icon: "dumbbell.fill", isDefault: false)
        let appBundle = try #require(
            Bundle.allBundles.first { $0.bundleIdentifier == "com.enerjiktech.vittora" }
        )

        #expect(englishDefaults.count == 26)
        #expect(spanishDefaults.count == 26)
        #expect(spanishIDs == englishIDs)
        #expect(englishEntity.displayName(locale: Locale(identifier: "en"), bundle: appBundle) == "Groceries")
        #expect(spanishEntity.displayName(locale: Locale(identifier: "es"), bundle: appBundle) == "Comestibles")
        #expect(spanishGroceries.name == "Groceries")
        #expect(customGym.displayName(locale: Locale(identifier: "es"), bundle: appBundle) == "Gym")
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
