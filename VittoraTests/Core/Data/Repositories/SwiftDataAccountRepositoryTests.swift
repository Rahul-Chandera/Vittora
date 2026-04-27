import Foundation
import Testing
import SwiftData
@testable import Vittora

@Suite("SwiftDataAccountRepository Tests")
struct SwiftDataAccountRepositoryTests {

    private func makeRepo() throws -> SwiftDataAccountRepository {
        let container = try ModelContainerConfig.makePreviewContainer()
        return SwiftDataAccountRepository(modelContainer: container)
    }

    @Test("create and fetchAll returns inserted entity")
    func testCreateAndFetchAll() async throws {
        let repo = try makeRepo()
        let entity = AccountEntity(
            id: UUID(),
            name: "Main Checking",
            type: .bank,
            balance: 1000,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try await repo.create(entity)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.id == entity.id)
        #expect(all.first?.name == "Main Checking")
        #expect(all.first?.type == .bank)
        #expect(all.first?.balance == 1000)
        #expect(all.first?.currencyCode == "USD")
    }

    @Test("fetchByID returns correct entity")
    func testFetchByID() async throws {
        let repo = try makeRepo()
        let id = UUID()
        let entity = AccountEntity(
            id: id,
            name: "Savings",
            type: .bank,
            balance: 500,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try await repo.create(entity)

        let found = try await repo.fetchByID(id)

        #expect(found != nil)
        #expect(found?.id == id)
        #expect(found?.name == "Savings")
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
        var entity = AccountEntity(
            id: id,
            name: "Old Name",
            type: .cash,
            balance: 100,
            currencyCode: "USD",
            createdAt: Date(timeIntervalSince1970: 3_000_000),
            updatedAt: Date(timeIntervalSince1970: 3_000_000)
        )
        try await repo.create(entity)

        entity.name = "New Name"
        entity.balance = 250
        entity.updatedAt = Date(timeIntervalSince1970: 3_100_000)
        try await repo.update(entity)

        let updated = try await repo.fetchByID(id)
        #expect(updated?.name == "New Name")
        #expect(updated?.balance == 250)
    }

    @Test("update throws notFound for missing ID")
    func testUpdateNotFound() async throws {
        let repo = try makeRepo()
        let entity = AccountEntity(
            id: UUID(),
            name: "Ghost",
            type: .bank,
            balance: 0,
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
        let entity = AccountEntity(
            id: id,
            name: "To Delete",
            type: .cash,
            balance: 0,
            currencyCode: "USD",
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

    @Test("fetchByType returns only matching account type")
    func testFetchByType() async throws {
        let repo = try makeRepo()
        let bankID = UUID()
        let cashID = UUID()

        try await repo.create(AccountEntity(
            id: bankID, name: "Bank Account", type: .bank,
            createdAt: Date(timeIntervalSince1970: 6_000_000),
            updatedAt: Date(timeIntervalSince1970: 6_000_000)
        ))
        try await repo.create(AccountEntity(
            id: cashID, name: "Cash Wallet", type: .cash,
            createdAt: Date(timeIntervalSince1970: 6_100_000),
            updatedAt: Date(timeIntervalSince1970: 6_100_000)
        ))

        let bankAccounts = try await repo.fetchByType(.bank)
        let cashAccounts = try await repo.fetchByType(.cash)

        #expect(bankAccounts.count == 1)
        #expect(bankAccounts.first?.id == bankID)
        #expect(cashAccounts.count == 1)
        #expect(cashAccounts.first?.id == cashID)
    }

    @Test("fetchByType returns empty array for type with no accounts")
    func testFetchByTypeEmpty() async throws {
        let repo = try makeRepo()

        let results = try await repo.fetchByType(.investment)

        #expect(results.isEmpty)
    }
}
