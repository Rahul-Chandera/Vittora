import Testing
import SwiftData
import Foundation
@testable import Vittora

/// Verifies the single-context write Unit-of-Work guarantees from A1:
/// a compound operation persists with exactly one `save()`, and an
/// operation that fails mid-way rolls back and persists nothing.
@Suite("LedgerWriteStore Unit-of-Work")
struct LedgerWriteStoreTests {

    /// Error used to simulate a failure injected partway through an operation.
    private struct InjectedFailure: Error {}

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerConfig.makeContainer(inMemory: true)
    }

    @Test("compound write persists all changes with exactly one save")
    func compoundWriteSavesOnce() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        try await store.commit { ctx in
            ctx.insert(SDTransaction(amount: 10, externalID: UUID().uuidString))
            ctx.insert(SDTransaction(amount: 20, externalID: UUID().uuidString))
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.count == 2)
    }

    @Test("mid-operation failure rolls back and persists nothing")
    func midOperationFailureRollsBack() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: InjectedFailure.self) {
            try await store.commit { ctx in
                ctx.insert(SDTransaction(amount: 99, externalID: UUID().uuidString))
                throw InjectedFailure()
            }
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 0)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.isEmpty)
    }

    @Test("store recovers after a failed operation")
    func storeRecoversAfterFailure() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: InjectedFailure.self) {
            try await store.commit { ctx in
                ctx.insert(SDTransaction(amount: 1, externalID: UUID().uuidString))
                throw InjectedFailure()
            }
        }

        try await store.commit { ctx in
            ctx.insert(SDTransaction(amount: 42, externalID: UUID().uuidString))
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.amount == 42)
    }

    @Test("seeded operation entry points throw until their task wires them")
    func seededEntryPointsNotImplemented() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: LedgerWriteError.self) {
            try await store.performAdd(TransactionEntity(amount: 5))
        }
    }
}
