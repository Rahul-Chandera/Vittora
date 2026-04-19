import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataBudgetRepository Tests")
struct SwiftDataBudgetRepositoryTests {

    private func makeRepo() throws -> SwiftDataBudgetRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataBudgetRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let categoryID = UUID()
        let entity = BudgetEntity(
            id: UUID(),
            amount: 500,
            spent: 0,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 1_000_000),
            rollover: false,
            categoryID: categoryID,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.amount == 500)
        #expect(all.first?.period == .monthly)
        #expect(all.first?.categoryID == categoryID)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = BudgetEntity(
            id: id,
            amount: 300,
            spent: 50,
            period: .weekly,
            startDate: Date(timeIntervalSince1970: 2_000_000),
            rollover: true,
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.amount == 300)
        #expect(found?.rollover == true)
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
        var entity = BudgetEntity(
            id: id,
            amount: 200,
            spent: 0,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 3_000_000),
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.amount = 400
        entity.spent = 150
        entity.rollover = true
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.amount == 400)
        #expect(updated?.spent == 150)
        #expect(updated?.rollover == true)
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = BudgetEntity(
            id: UUID(),
            amount: 100,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 4_000_000),
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
        let entity = BudgetEntity(
            id: id,
            amount: 150,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 5_000_000),
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

    @Test("fetchActive returns all budgets whose startDate is in the past")
    func testFetchActive() async throws {
        let repo = try makeRepo()
        let pastDate = Date(timeIntervalSince1970: 1_000_000)
        let futureDate = Date(timeIntervalSinceNow: 86_400 * 365)

        try await repo.create(BudgetEntity(
            id: UUID(), amount: 100, period: .monthly, startDate: pastDate,
            createdAt: pastDate, updatedAt: pastDate
        ))
        try await repo.create(BudgetEntity(
            id: UUID(), amount: 200, period: .weekly, startDate: futureDate,
            createdAt: pastDate, updatedAt: pastDate
        ))

        let active = try await repo.fetchActive()

        // fetchActive predicates startDate <= now — past-start budget should be included
        let activeIDs = active.map(\.startDate)
        #expect(activeIDs.contains(pastDate))
    }

    // MARK: - fetchForCategory

    @Test("fetchForCategory returns matching budget for category and period")
    func testFetchForCategory() async throws {
        let repo = try makeRepo()
        let catID = UUID()
        let entity = BudgetEntity(
            id: UUID(),
            amount: 750,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 6_000_000),
            categoryID: catID,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchForCategory(catID, period: .monthly)

        #expect(found != nil)
        #expect(found?.categoryID == catID)
        #expect(found?.period == .monthly)
    }

    @Test("fetchForCategory returns nil when period does not match")
    func testFetchForCategoryWrongPeriod() async throws {
        let repo = try makeRepo()
        let catID = UUID()
        try await repo.create(BudgetEntity(
            id: UUID(), amount: 500, period: .monthly,
            startDate: Date(timeIntervalSince1970: 7_000_000),
            categoryID: catID,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let found = try await repo.fetchForCategory(catID, period: .weekly)

        #expect(found == nil)
    }

    @Test("fetchForCategory returns nil for unknown category ID")
    func testFetchForCategoryUnknownID() async throws {
        let repo = try makeRepo()

        let found = try await repo.fetchForCategory(UUID(), period: .monthly)

        #expect(found == nil)
    }
}
