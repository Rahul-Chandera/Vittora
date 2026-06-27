import Testing
import SwiftData
import Foundation
@testable import Vittora

/// Uses V1 versioned schema with migration-plan scaffolding.
@Suite("ModelContainer (versioned schema)")
@MainActor
struct ModelContainerConfigTests {

    @Test("in-memory container loads")
    func inMemoryContainerLoads() throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        #expect(container.configurations.isEmpty == false)
    }

    @Test("container allows insert and fetch")
    func insertAndFetch() throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let ctx = ModelContext(container)
        let tx = SDTransaction(amount: 42, externalID: UUID().uuidString)
        ctx.insert(tx)
        try ctx.save()
        let txs = try ctx.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.count == 1)
        #expect(txs.first?.amount == 42)
    }

    @Test("SDDocument matches current filesystem-backed shape")
    func sdDocumentShape() {
        let doc = SDDocument()
        #expect(doc.fileName == "")
        #expect(doc.mimeType == "image/jpeg")
        #expect(doc.transactionID == nil)
    }

    @Test("migration plan declares V1–V4 with lightweight stages")
    func migrationPlanShape() {
        #expect(VittoraMigrationPlan.schemas.count == 4)
        #expect(VittoraMigrationPlan.stages.count == 3)
        #expect(VittoraSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(VittoraSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(VittoraSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(VittoraSchemaV4.versionIdentifier == Schema.Version(4, 0, 0))
    }

    // NOTE: This is a persistence round-trip at the current (V2) schema — it
    // closes and reopens an on-disk store — not a V1→V2 migration test. A
    // faithful V1→V2 migration test (frozen V1 snapshot without transferPairID)
    // is tracked under I4; see EXECUTION_PLAN.md.
    @Test("on-disk store round-trips transactions including transferPairID")
    func onDiskStoreRoundTripsTransferPairID() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-roundtrip-test.store")

        let pairID = UUID()
        let transferLegID = UUID()
        let plainTxID = UUID()

        // First open: create the store and seed two rows (one carrying a pair id).
        do {
            let schema = Schema(VittoraSchemaV2.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(SDTransaction(
                id: transferLegID,
                amount: 100,
                type: .transfer,
                transferPairID: pairID,
                externalID: UUID().uuidString
            ))
            ctx.insert(SDTransaction(
                id: plainTxID,
                amount: 50,
                externalID: UUID().uuidString
            ))
            try ctx.save()
        }

        // Second open: reopen the same on-disk store (migration plan attached).
        let schema = Schema(VittoraSchemaV2.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDTransaction>())

        #expect(rows.count == 2)
        let reloadedLeg = rows.first { $0.id == transferLegID }
        let reloadedPlain = rows.first { $0.id == plainTxID }
        #expect(reloadedLeg?.amount == 100)
        #expect(reloadedLeg?.transferPairID == pairID)
        #expect(reloadedPlain?.amount == 50)
        #expect(reloadedPlain?.transferPairID == nil)
    }

    // Schema V3 (DATAINTEGRITY-1, A3): persistence round-trip at the current
    // schema for the additive optional `transferDirection` — debit, credit, and
    // nil (non-transfer/legacy) must all survive a close/reopen of an on-disk store.
    @Test("on-disk store round-trips transfer leg direction (debit/credit/nil)")
    func onDiskStoreRoundTripsTransferDirection() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-direction-roundtrip.store")

        let pairID = UUID()
        let debitID = UUID()
        let creditID = UUID()
        let plainID = UUID()

        do {
            let schema = Schema(VittoraSchemaV4.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(SDTransaction(
                id: debitID, amount: 100, type: .transfer,
                transferPairID: pairID, transferDirection: .debit, externalID: UUID().uuidString
            ))
            ctx.insert(SDTransaction(
                id: creditID, amount: 100, type: .transfer,
                transferPairID: pairID, transferDirection: .credit, externalID: UUID().uuidString
            ))
            ctx.insert(SDTransaction(id: plainID, amount: 50, externalID: UUID().uuidString))
            try ctx.save()
        }

        let schema = Schema(VittoraSchemaV4.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDTransaction>())

        #expect(rows.count == 3)
        #expect(rows.first { $0.id == debitID }?.transferDirection == .debit)
        #expect(rows.first { $0.id == creditID }?.transferDirection == .credit)
        #expect(rows.first { $0.id == plainID }?.transferDirection == nil)
    }

    // Schema V4 (DATAINTEGRITY-12, A7): persistence round-trip at the current
    // schema for the additive optional `openingBalance` — a set value and a nil
    // value must both survive a close/reopen of an on-disk store.
    @Test("on-disk store round-trips account openingBalance (set and nil)")
    func onDiskStoreRoundTripsOpeningBalance() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-opening-roundtrip.store")

        let withOpeningID = UUID()
        let legacyID = UUID()

        do {
            let schema = Schema(VittoraSchemaV4.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(SDAccount(id: withOpeningID, name: "Seeded", type: .bank, balance: 500, openingBalance: 1000))
            ctx.insert(SDAccount(id: legacyID, name: "Legacy", type: .bank, balance: 500, openingBalance: nil))
            try ctx.save()
        }

        let schema = Schema(VittoraSchemaV4.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDAccount>())

        #expect(rows.count == 2)
        #expect(rows.first { $0.id == withOpeningID }?.openingBalance == 1000)
        #expect(rows.first { $0.id == legacyID }?.openingBalance == nil)
    }
}
