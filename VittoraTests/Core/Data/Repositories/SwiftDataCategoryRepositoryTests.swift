import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataCategoryRepository Tests")
struct SwiftDataCategoryRepositoryTests {

    private func makeRepo() throws -> SwiftDataCategoryRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataCategoryRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = CategoryEntity(
            id: UUID(),
            name: "Food",
            icon: "fork.knife",
            colorHex: "#FF6B6B",
            type: .expense,
            isDefault: false,
            sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.name == "Food")
        #expect(all.first?.icon == "fork.knife")
        #expect(all.first?.colorHex == "#FF6B6B")
        #expect(all.first?.type == .expense)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = CategoryEntity(
            id: id,
            name: "Transport",
            icon: "car.fill",
            colorHex: "#4ECDC4",
            type: .expense,
            sortOrder: 2,
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.name == "Transport")
    }

    @Test("fetchByID returns nil for unknown ID")
    func testFetchByIDReturnsNil() async throws {
        let repo = try makeRepo()

        let result = try await repo.fetchByID(UUID())

        #expect(result == nil)
    }

    @Test("update modifies persisted fields")
    func testUpdate() async throws {
        let repo = try makeRepo()
        let id = UUID()
        var entity = CategoryEntity(
            id: id,
            name: "Shopping",
            icon: "bag.fill",
            colorHex: "#FFE66D",
            type: .expense,
            sortOrder: 3,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.name = "Online Shopping"
        entity.colorHex = "#F7DC6F"
        entity.sortOrder = 5
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.name == "Online Shopping")
        #expect(updated?.colorHex == "#F7DC6F")
        #expect(updated?.sortOrder == 5)
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = CategoryEntity(
            id: UUID(),
            name: "Ghost",
            icon: "star",
            createdAt: Date(timeIntervalSince1970: 4_000_000),
            updatedAt: Date(timeIntervalSince1970: 4_000_000)
        )

        do {
            try await repo.update(entity)
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    @Test("delete removes entity")
    func testDelete() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = CategoryEntity(
            id: id,
            name: "Health",
            icon: "heart.fill",
            createdAt: Date(timeIntervalSince1970: 5_000_000),
            updatedAt: Date(timeIntervalSince1970: 5_000_000)
        )
        try await repo.create(entity)

        try await repo.delete(id)
        let all = try await repo.fetchAll()

        #expect(all.isEmpty)
    }

    @Test("delete throws notFound for missing ID")
    func testDeleteNotFound() async throws {
        let repo = try makeRepo()

        do {
            try await repo.delete(UUID())
            #expect(Bool(false), "Expected error was not thrown")
        } catch let error as VittoraError {
            if case .notFound = error { } else {
                #expect(Bool(false), "Expected notFound error")
            }
        }
    }

    // MARK: - fetchDefaults

    @Test("fetchDefaults returns only default categories")
    func testFetchDefaults() async throws {
        let repo = try makeRepo()

        try await repo.create(CategoryEntity(
            id: UUID(), name: "Default Cat", icon: "star",
            isDefault: true, sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(CategoryEntity(
            id: UUID(), name: "Custom Cat", icon: "tag",
            isDefault: false, sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))

        let defaults = try await repo.fetchDefaults()

        #expect(defaults.count == 1)
        #expect(defaults.first?.name == "Default Cat")
        #expect(defaults.first?.isDefault == true)
    }

    @Test("fetchDefaults returns empty when no default categories exist")
    func testFetchDefaultsEmpty() async throws {
        let repo = try makeRepo()
        try await repo.create(CategoryEntity(
            id: UUID(), name: "Custom", icon: "tag",
            isDefault: false, sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let defaults = try await repo.fetchDefaults()

        #expect(defaults.isEmpty)
    }

    // MARK: - fetchByType

    @Test("fetchByType returns only categories matching the given type")
    func testFetchByType() async throws {
        let repo = try makeRepo()

        try await repo.create(CategoryEntity(
            id: UUID(), name: "Salary", icon: "briefcase",
            type: .income, sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 8_000_000),
            updatedAt: Date(timeIntervalSince1970: 8_000_000)
        ))
        try await repo.create(CategoryEntity(
            id: UUID(), name: "Rent", icon: "house",
            type: .expense, sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 8_100_000),
            updatedAt: Date(timeIntervalSince1970: 8_100_000)
        ))

        let incomeCategories = try await repo.fetchByType(.income)
        let expenseCategories = try await repo.fetchByType(.expense)

        #expect(incomeCategories.count == 1)
        #expect(incomeCategories.first?.name == "Salary")
        #expect(expenseCategories.count == 1)
        #expect(expenseCategories.first?.name == "Rent")
    }

    @Test("fetchByType returns empty array when no categories match")
    func testFetchByTypeEmpty() async throws {
        let repo = try makeRepo()

        let results = try await repo.fetchByType(.income)

        #expect(results.isEmpty)
    }
}
