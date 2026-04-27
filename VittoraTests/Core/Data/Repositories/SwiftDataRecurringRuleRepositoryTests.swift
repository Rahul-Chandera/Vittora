import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataRecurringRuleRepository Tests")
struct SwiftDataRecurringRuleRepositoryTests {

    private func makeRepo() throws -> SwiftDataRecurringRuleRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataRecurringRuleRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = RecurringRuleEntity(
            id: UUID(),
            frequency: .monthly,
            nextDate: Date(timeIntervalSince1970: 2_000_000),
            isActive: true,
            templateAmount: 1_200,
            templateNote: "Rent",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.templateAmount == 1_200)
        #expect(all.first?.templateNote == "Rent")
        #expect(all.first?.isActive == true)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = RecurringRuleEntity(
            id: id,
            frequency: .weekly,
            nextDate: Date(timeIntervalSince1970: 3_000_000),
            isActive: true,
            templateAmount: 50,
            templateNote: "Grocery run",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.templateNote == "Grocery run")
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
        var entity = RecurringRuleEntity(
            id: id,
            frequency: .daily,
            nextDate: Date(timeIntervalSince1970: 4_000_000),
            isActive: true,
            templateAmount: 10,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.isActive = false
        entity.templateAmount = 15
        entity.templateNote = "Daily coffee"
        entity.nextDate = Date(timeIntervalSince1970: 4_100_000)
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.isActive == false)
        #expect(updated?.templateAmount == 15)
        #expect(updated?.templateNote == "Daily coffee")
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = RecurringRuleEntity(
            id: UUID(),
            frequency: .monthly,
            nextDate: Date(timeIntervalSince1970: 5_000_000),
            templateAmount: 100,
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
        let entity = RecurringRuleEntity(
            id: id,
            frequency: .yearly,
            nextDate: Date(timeIntervalSince1970: 6_000_000),
            templateAmount: 5_000,
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

    // MARK: - fetchActive

    @Test("fetchActive returns only active recurring rules")
    func testFetchActive() async throws {
        let repo = try makeRepo()

        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .monthly,
            nextDate: Date(timeIntervalSince1970: 8_000_000),
            isActive: true,
            templateAmount: 500,
            templateNote: "Active Rule",
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))
        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .weekly,
            nextDate: Date(timeIntervalSince1970: 9_000_000),
            isActive: false,
            templateAmount: 100,
            templateNote: "Inactive Rule",
            createdAt: Date(timeIntervalSince1970: 7_100_000),
            updatedAt: Date(timeIntervalSince1970: 7_100_000)
        ))

        let active = try await repo.fetchActive()

        #expect(active.count == 1)
        #expect(active.first?.templateNote == "Active Rule")
        #expect(active.first?.isActive == true)
    }

    @Test("fetchActive returns empty when no active rules exist")
    func testFetchActiveEmpty() async throws {
        let repo = try makeRepo()
        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .monthly,
            nextDate: Date(timeIntervalSince1970: 10_000_000),
            isActive: false,
            templateAmount: 200,
            createdAt: Date(timeIntervalSince1970: 9_000_000),
            updatedAt: Date(timeIntervalSince1970: 9_000_000)
        ))

        let active = try await repo.fetchActive()

        #expect(active.isEmpty)
    }

    // MARK: - fetchDueRules

    @Test("fetchDueRules returns active rules whose nextDate is before the given date")
    func testFetchDueRules() async throws {
        let repo = try makeRepo()
        let dueDate = Date(timeIntervalSince1970: 5_000_000)
        let futureDate = Date(timeIntervalSince1970: 99_000_000_000)
        let checkDate = Date(timeIntervalSince1970: 6_000_000)

        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .monthly,
            nextDate: dueDate,
            isActive: true,
            templateAmount: 300,
            templateNote: "Due Rule",
            createdAt: Date(timeIntervalSince1970: 11_000_000),
            updatedAt: Date(timeIntervalSince1970: 11_000_000)
        ))
        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .weekly,
            nextDate: futureDate,
            isActive: true,
            templateAmount: 50,
            templateNote: "Future Rule",
            createdAt: Date(timeIntervalSince1970: 11_100_000),
            updatedAt: Date(timeIntervalSince1970: 11_100_000)
        ))

        let dueRules = try await repo.fetchDueRules(before: checkDate)

        #expect(dueRules.count == 1)
        #expect(dueRules.first?.templateNote == "Due Rule")
    }

    @Test("fetchDueRules excludes inactive rules even if nextDate is past")
    func testFetchDueRulesExcludesInactive() async throws {
        let repo = try makeRepo()
        let dueDate = Date(timeIntervalSince1970: 1_000_000)
        let checkDate = Date(timeIntervalSince1970: 2_000_000)

        try await repo.create(RecurringRuleEntity(
            id: UUID(),
            frequency: .daily,
            nextDate: dueDate,
            isActive: false,
            templateAmount: 10,
            createdAt: Date(timeIntervalSince1970: 12_000_000),
            updatedAt: Date(timeIntervalSince1970: 12_000_000)
        ))

        let dueRules = try await repo.fetchDueRules(before: checkDate)

        #expect(dueRules.isEmpty)
    }
}
