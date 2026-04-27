import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataTransactionRepository Tests")
struct SwiftDataTransactionRepositoryTests {

    private func makeRepo() throws -> SwiftDataTransactionRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataTransactionRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = TransactionEntity(
            id: UUID(),
            amount: 42.50,
            date: Date(timeIntervalSince1970: 1_000_000),
            note: "Lunch",
            type: .expense,
            paymentMethod: .cash,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll(filter: nil)

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.amount == 42.50)
        #expect(all.first?.note == "Lunch")
        #expect(all.first?.type == .expense)
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = TransactionEntity(
            id: id,
            amount: 99.99,
            date: Date(timeIntervalSince1970: 2_000_000),
            note: "Dinner",
            type: .expense,
            paymentMethod: .creditCard,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.amount == 99.99)
        #expect(found?.note == "Dinner")
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
        var entity = TransactionEntity(
            id: id,
            amount: 10.00,
            date: Date(timeIntervalSince1970: 3_000_000),
            note: "Original note",
            type: .expense,
            paymentMethod: .cash,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.amount = 20.00
        entity.note = "Updated note"
        entity.type = .income
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.amount == 20.00)
        #expect(updated?.note == "Updated note")
        #expect(updated?.type == .income)
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = TransactionEntity(
            id: UUID(),
            amount: 5.00,
            date: Date(timeIntervalSince1970: 4_000_000),
            type: .expense,
            paymentMethod: .cash,
            currencyCode: "USD",
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
        let entity = TransactionEntity(
            id: id,
            amount: 15.00,
            date: Date(timeIntervalSince1970: 5_000_000),
            type: .expense,
            paymentMethod: .cash,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 5_000_000),
            updatedAt: Date(timeIntervalSince1970: 5_000_000)
        )
        try await repo.create(entity)

        try await repo.delete(id)
        let all = try await repo.fetchAll(filter: nil)

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

    // MARK: - bulkDelete

    @Test("bulkDelete removes all specified entities")
    func testBulkDelete() async throws {
        let repo = try makeRepo()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        try await repo.create(TransactionEntity(
            id: id1, amount: 10, date: Date(timeIntervalSince1970: 6_000_000),
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(TransactionEntity(
            id: id2, amount: 20, date: Date(timeIntervalSince1970: 6_100_000),
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))
        try await repo.create(TransactionEntity(
            id: id3, amount: 30, date: Date(timeIntervalSince1970: 6_200_000),
            type: .income, paymentMethod: .bankTransfer, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 6_200_000),
            updatedAt: Date(timeIntervalSince1970: 6_200_000)
        ))

        try await repo.bulkDelete([id1, id2])
        let remaining = try await repo.fetchAll(filter: nil)

        #expect(remaining.count == 1)
        #expect(remaining.first?.id == id3)
    }

    @Test("bulkDelete with unknown IDs does not throw")
    func testBulkDeleteUnknownIDs() async throws {
        let repo = try makeRepo()

        // Should not throw even if IDs don't exist
        try await repo.bulkDelete([UUID(), UUID()])
        let all = try await repo.fetchAll(filter: nil)
        #expect(all.isEmpty)
    }

    // MARK: - search

    @Test("search returns transactions matching note query")
    func testSearch() async throws {
        let repo = try makeRepo()

        try await repo.create(TransactionEntity(
            id: UUID(), amount: 50, date: Date(timeIntervalSince1970: 7_000_000),
            note: "Coffee at Starbucks",
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))
        try await repo.create(TransactionEntity(
            id: UUID(), amount: 25, date: Date(timeIntervalSince1970: 7_100_000),
            note: "Monthly salary",
            type: .income, paymentMethod: .bankTransfer, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 7_100_000),
            updatedAt: Date(timeIntervalSince1970: 7_100_000)
        ))

        let results = try await repo.search(query: "coffee")

        #expect(results.count == 1)
        #expect(results.first?.note == "Coffee at Starbucks")
    }

    @Test("search returns empty for no matching note")
    func testSearchNoMatch() async throws {
        let repo = try makeRepo()
        try await repo.create(TransactionEntity(
            id: UUID(), amount: 10, date: Date(timeIntervalSince1970: 8_000_000),
            note: "Groceries",
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 8_000_000),
            updatedAt: Date(timeIntervalSince1970: 8_000_000)
        ))

        let results = try await repo.search(query: "xyz_nonexistent")

        #expect(results.isEmpty)
    }

    // MARK: - fetchAll with filter

    @Test("fetchAll with date range filter returns matching transactions")
    func testFetchAllWithDateRangeFilter() async throws {
        let repo = try makeRepo()
        let earlyDate = Date(timeIntervalSince1970: 9_000_000)
        let lateDate = Date(timeIntervalSince1970: 9_500_000)
        let outsideDate = Date(timeIntervalSince1970: 10_000_000)

        try await repo.create(TransactionEntity(
            id: UUID(), amount: 10, date: earlyDate,
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: earlyDate, updatedAt: earlyDate
        ))
        try await repo.create(TransactionEntity(
            id: UUID(), amount: 20, date: lateDate,
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: lateDate, updatedAt: lateDate
        ))
        try await repo.create(TransactionEntity(
            id: UUID(), amount: 30, date: outsideDate,
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: outsideDate, updatedAt: outsideDate
        ))

        let filter = TransactionFilter(dateRange: earlyDate...lateDate)
        let results = try await repo.fetchAll(filter: filter)

        #expect(results.count == 2)
    }

    @Test("fetchAll with type filter returns only matching transactions")
    func testFetchAllWithTypeFilter() async throws {
        let repo = try makeRepo()

        try await repo.create(TransactionEntity(
            id: UUID(), amount: 100, date: Date(timeIntervalSince1970: 11_000_000),
            type: .income, paymentMethod: .bankTransfer, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 11_000_000),
            updatedAt: Date(timeIntervalSince1970: 11_000_000)
        ))
        try await repo.create(TransactionEntity(
            id: UUID(), amount: 50, date: Date(timeIntervalSince1970: 11_100_000),
            type: .expense, paymentMethod: .cash, currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 11_100_000),
            updatedAt: Date(timeIntervalSince1970: 11_100_000)
        ))

        let filter = TransactionFilter(types: [.income])
        let results = try await repo.fetchAll(filter: filter)

        #expect(results.count == 1)
        #expect(results.first?.type == .income)
    }

    @Test("fetchAll with nil filter returns all transactions")
    func testFetchAllNilFilter() async throws {
        let repo = try makeRepo()

        for i in 0..<3 {
            try await repo.create(TransactionEntity(
                id: UUID(),
                amount: Decimal(i * 10 + 5),
                date: Date(timeIntervalSince1970: Double(12_000_000 + i * 100_000)),
                type: .expense, paymentMethod: .cash, currencyCode: "USD",
                createdAt: Date(timeIntervalSince1970: Double(12_000_000 + i * 100_000)),
                updatedAt: Date(timeIntervalSince1970: Double(12_000_000 + i * 100_000))
            ))
        }

        let all = try await repo.fetchAll(filter: nil)

        #expect(all.count == 3)
    }
}
