import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataSavingsGoalRepository Tests")
struct SwiftDataSavingsGoalRepositoryTests {

    private func makeRepo() throws -> SwiftDataSavingsGoalRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataSavingsGoalRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = SavingsGoalEntity(
            id: UUID(),
            name: "Emergency Fund",
            category: .emergency,
            targetAmount: 10_000,
            currentAmount: 2_500,
            status: .active,
            colorHex: "#5856D6",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.name == "Emergency Fund")
        #expect(all.first?.category == .emergency)
        #expect(all.first?.targetAmount == 10_000)
        #expect(all.first?.currentAmount == 2_500)
        #expect(all.first?.status == .active)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = SavingsGoalEntity(
            id: id,
            name: "Travel to Japan",
            category: .travel,
            targetAmount: 5_000,
            status: .active,
            colorHex: "#FF6B6B",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.name == "Travel to Japan")
        #expect(found?.category == .travel)
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
        var entity = SavingsGoalEntity(
            id: id,
            name: "Old Goal",
            category: .other,
            targetAmount: 1_000,
            currentAmount: 0,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.name = "Updated Goal"
        entity.currentAmount = 500
        entity.status = .paused
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.name == "Updated Goal")
        #expect(updated?.currentAmount == 500)
        #expect(updated?.status == .paused)
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = SavingsGoalEntity(
            id: UUID(),
            name: "Ghost Goal",
            category: .other,
            targetAmount: 100,
            status: .active,
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
        let entity = SavingsGoalEntity(
            id: id,
            name: "To Delete",
            category: .other,
            targetAmount: 500,
            status: .active,
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

    @Test("fetchActive returns only active savings goals")
    func testFetchActive() async throws {
        let repo = try makeRepo()

        try await repo.create(SavingsGoalEntity(
            id: UUID(), name: "Active Goal", category: .home,
            targetAmount: 20_000, status: .active,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(SavingsGoalEntity(
            id: UUID(), name: "Achieved Goal", category: .travel,
            targetAmount: 5_000, currentAmount: 5_000, status: .achieved,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))
        try await repo.create(SavingsGoalEntity(
            id: UUID(), name: "Cancelled Goal", category: .other,
            targetAmount: 1_000, status: .cancelled,
            createdAt: Date(timeIntervalSince1970: 6_200_000),
            updatedAt: Date(timeIntervalSince1970: 6_200_000)
        ))

        let active = try await repo.fetchActive()

        #expect(active.count == 1)
        #expect(active.first?.name == "Active Goal")
        #expect(active.first?.status == .active)
    }

    @Test("fetchActive returns empty when no active goals exist")
    func testFetchActiveEmpty() async throws {
        let repo = try makeRepo()
        try await repo.create(SavingsGoalEntity(
            id: UUID(), name: "Paused", category: .other,
            targetAmount: 500, status: .paused,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let active = try await repo.fetchActive()

        #expect(active.isEmpty)
    }
}
