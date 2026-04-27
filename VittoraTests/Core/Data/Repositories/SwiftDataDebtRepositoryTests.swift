import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataDebtRepository Tests")
struct SwiftDataDebtRepositoryTests {

    private func makeRepo() throws -> SwiftDataDebtRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataDebtRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let payeeID = UUID()
        let entity = DebtEntry(
            id: UUID(),
            payeeID: payeeID,
            amount: 200,
            settledAmount: 0,
            direction: .lent,
            note: "Lunch money",
            isSettled: false,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.payeeID == payeeID)
        #expect(all.first?.amount == 200)
        #expect(all.first?.direction == .lent)
        #expect(all.first?.isSettled == false)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = DebtEntry(
            id: id,
            payeeID: UUID(),
            amount: 500,
            direction: .borrowed,
            note: "Borrowed for car repair",
            isSettled: false,
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.amount == 500)
        #expect(found?.direction == .borrowed)
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
        var entity = DebtEntry(
            id: id,
            payeeID: UUID(),
            amount: 300,
            settledAmount: 0,
            direction: .lent,
            isSettled: false,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.settledAmount = 300
        entity.isSettled = true
        entity.note = "Fully repaid"
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.settledAmount == 300)
        #expect(updated?.isSettled == true)
        #expect(updated?.note == "Fully repaid")
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = DebtEntry(
            id: UUID(),
            payeeID: UUID(),
            amount: 50,
            direction: .lent,
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
        let entity = DebtEntry(
            id: id,
            payeeID: UUID(),
            amount: 100,
            direction: .borrowed,
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

    // MARK: - fetchOutstanding

    @Test("fetchOutstanding returns only unsettled debts")
    func testFetchOutstanding() async throws {
        let repo = try makeRepo()

        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 100,
            direction: .lent, isSettled: false,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 200,
            direction: .borrowed, isSettled: true,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))

        let outstanding = try await repo.fetchOutstanding()

        #expect(outstanding.count == 1)
        #expect(outstanding.first?.isSettled == false)
        #expect(outstanding.first?.amount == 100)
    }

    @Test("fetchOutstanding returns empty when all debts are settled")
    func testFetchOutstandingAllSettled() async throws {
        let repo = try makeRepo()
        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 50,
            direction: .lent, isSettled: true,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let outstanding = try await repo.fetchOutstanding()

        #expect(outstanding.isEmpty)
    }

    // MARK: - fetchForPayee

    @Test("fetchForPayee returns only debts associated with the given payee")
    func testFetchForPayee() async throws {
        let repo = try makeRepo()
        let targetPayeeID = UUID()
        let otherPayeeID = UUID()

        try await repo.create(DebtEntry(
            id: UUID(), payeeID: targetPayeeID, amount: 150,
            direction: .lent, isSettled: false,
            createdAt: Date(timeIntervalSince1970: 8_000_000),
            updatedAt: Date(timeIntervalSince1970: 8_000_000)
        ))
        try await repo.create(DebtEntry(
            id: UUID(), payeeID: otherPayeeID, amount: 75,
            direction: .borrowed, isSettled: false,
            createdAt: Date(timeIntervalSince1970: 8_100_000),
            updatedAt: Date(timeIntervalSince1970: 8_100_000)
        ))

        let results = try await repo.fetchForPayee(targetPayeeID)

        #expect(results.count == 1)
        #expect(results.first?.payeeID == targetPayeeID)
    }

    @Test("fetchForPayee returns empty for unknown payee")
    func testFetchForPayeeUnknown() async throws {
        let repo = try makeRepo()

        let results = try await repo.fetchForPayee(UUID())

        #expect(results.isEmpty)
    }

    // MARK: - fetchOverdue

    @Test("fetchOverdue returns unsettled debts whose due date is before the given date")
    func testFetchOverdue() async throws {
        let repo = try makeRepo()
        let pastDue = Date(timeIntervalSince1970: 1_000_000)
        let futureDue = Date(timeIntervalSince1970: 99_000_000_000)
        let checkDate = Date(timeIntervalSince1970: 2_000_000)

        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 100,
            direction: .lent, dueDate: pastDue, isSettled: false,
            createdAt: Date(timeIntervalSince1970: 9_000_000),
            updatedAt: Date(timeIntervalSince1970: 9_000_000)
        ))
        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 200,
            direction: .borrowed, dueDate: futureDue, isSettled: false,
            createdAt: Date(timeIntervalSince1970: 9_100_000),
            updatedAt: Date(timeIntervalSince1970: 9_100_000)
        ))

        let overdue = try await repo.fetchOverdue(before: checkDate)

        #expect(overdue.count == 1)
        #expect(overdue.first?.amount == 100)
    }

    @Test("fetchOverdue excludes settled debts even if due date has passed")
    func testFetchOverdueExcludesSettled() async throws {
        let repo = try makeRepo()
        let pastDue = Date(timeIntervalSince1970: 1_000_000)
        let checkDate = Date(timeIntervalSince1970: 2_000_000)

        try await repo.create(DebtEntry(
            id: UUID(), payeeID: UUID(), amount: 50,
            direction: .lent, dueDate: pastDue, isSettled: true,
            createdAt: Date(timeIntervalSince1970: 10_000_000),
            updatedAt: Date(timeIntervalSince1970: 10_000_000)
        ))

        let overdue = try await repo.fetchOverdue(before: checkDate)

        #expect(overdue.isEmpty)
    }
}
