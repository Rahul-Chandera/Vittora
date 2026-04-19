import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataPayeeRepository Tests")
struct SwiftDataPayeeRepositoryTests {

    private func makeRepo() throws -> SwiftDataPayeeRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataPayeeRepository(modelContainer: container)
    }

    // MARK: - Basic CRUD

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = PayeeEntity(
            id: UUID(),
            name: "Amazon",
            type: .business,
            phone: nil,
            email: "support@amazon.com",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.name == "Amazon")
        #expect(all.first?.type == .business)
        #expect(all.first?.email == "support@amazon.com")
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = PayeeEntity(
            id: id,
            name: "John Doe",
            type: .person,
            phone: "+1-555-0100",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.name == "John Doe")
        #expect(found?.type == .person)
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
        var entity = PayeeEntity(
            id: id,
            name: "Old Name",
            type: .business,
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.name = "New Name"
        entity.phone = "+1-555-9999"
        entity.notes = "VIP customer"
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.name == "New Name")
        #expect(updated?.phone == "+1-555-9999")
        #expect(updated?.notes == "VIP customer")
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = PayeeEntity(
            id: UUID(),
            name: "Ghost",
            type: .person,
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
        let entity = PayeeEntity(
            id: id,
            name: "To Delete",
            type: .business,
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

    // MARK: - search

    @Test("search returns payees matching name query")
    func testSearch() async throws {
        let repo = try makeRepo()

        try await repo.create(PayeeEntity(
            id: UUID(), name: "Starbucks Coffee", type: .business,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(PayeeEntity(
            id: UUID(), name: "Netflix", type: .business,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))

        let results = try await repo.search(query: "star")

        #expect(results.count == 1)
        #expect(results.first?.name == "Starbucks Coffee")
    }

    @Test("search returns empty for no matching payee")
    func testSearchNoMatch() async throws {
        let repo = try makeRepo()
        try await repo.create(PayeeEntity(
            id: UUID(), name: "Apple", type: .business,
            createdAt: Date(timeIntervalSince1970: 7_000_000),
            updatedAt: Date(timeIntervalSince1970: 7_000_000)
        ))

        let results = try await repo.search(query: "xyz_nonexistent")

        #expect(results.isEmpty)
    }

    // MARK: - fetchFrequent

    @Test("fetchFrequent respects the limit parameter")
    func testFetchFrequent() async throws {
        let repo = try makeRepo()

        for i in 0..<5 {
            try await repo.create(PayeeEntity(
                id: UUID(),
                name: "Payee \(i)",
                type: .business,
                createdAt: Date(timeIntervalSince1970: Double(8_000_000 + i * 100_000)),
                updatedAt: Date(timeIntervalSince1970: Double(8_000_000 + i * 100_000))
            ))
        }

        let frequent = try await repo.fetchFrequent(limit: 3)

        #expect(frequent.count == 3)
    }

    @Test("fetchFrequent returns all payees when limit exceeds count")
    func testFetchFrequentLimitExceedsCount() async throws {
        let repo = try makeRepo()

        try await repo.create(PayeeEntity(
            id: UUID(), name: "Only Payee", type: .business,
            createdAt: Date(timeIntervalSince1970: 9_000_000),
            updatedAt: Date(timeIntervalSince1970: 9_000_000)
        ))

        let frequent = try await repo.fetchFrequent(limit: 10)

        #expect(frequent.count == 1)
    }
}
