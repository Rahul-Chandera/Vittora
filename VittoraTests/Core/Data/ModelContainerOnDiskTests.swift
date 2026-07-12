import Testing
import SwiftData
import Foundation
import VittoraCore
@testable import Vittora

/// On-disk migration and round-trip tests — run via `make test-data` only.
/// They hang or destabilize the full CI unit-test batch when run together.
@Suite("ModelContainer (on-disk persistence)", .serialized)
@MainActor
struct ModelContainerOnDiskTests {

    /// Seeds an on-disk store at **Schema V1** (nested snapshot without `transferPairID`),
    /// reopens at Schema V2 with `VittoraMigrationPlan`, and asserts legacy rows survive
    /// with `transferPairID == nil` until explicitly set post-migrate.
    @Test("on-disk V1 store migrates to V2 preserving transaction data")
    func onDiskStoreMigratesV1ToV2() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-v1-migration.store")

        let txID = UUID()
        let accountID = UUID()
        let amount: Decimal = 125.50
        let note = "pre-V2 row"
        let externalID = UUID().uuidString
        let seededAt = Date(timeIntervalSince1970: 1_700_000_000)

        // Phase 1: create a fresh on-disk store at Schema V1 (no migration plan).
        do {
            let v1Schema = Schema(VittoraSchemaV1.models)
            let config = ModelConfiguration(schema: v1Schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: v1Schema, configurations: [config])
            let ctx = ModelContext(container)
            ctx.insert(VittoraSchemaV1.SDTransaction(
                id: txID,
                amount: amount,
                date: seededAt,
                note: note,
                type: .expense,
                accountID: accountID,
                externalID: externalID
            ))
            try ctx.save()
        }

        // Phase 2: reopen at Schema V2; the lightweight V1→V2 stage runs on open.
        let v2Schema = Schema(VittoraSchemaV2.models)
        let config = ModelConfiguration(schema: v2Schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: v2Schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<VittoraSchemaV2.SDTransaction>())
        let migrated = try #require(rows.first { $0.id == txID })

        #expect(rows.count == 1)
        #expect(migrated.amount == amount)
        #expect(migrated.note == note)
        #expect(migrated.accountID == accountID)
        #expect(migrated.externalID == externalID)
        #expect(migrated.date == seededAt)
        #expect(migrated.transferPairID == nil)

        let pairID = UUID()
        migrated.type = .transfer
        migrated.transferPairID = pairID
        try ctx.save()

        // Phase 3: round-trip at V2 to confirm the new column persists.
        let reopened = try ModelContainer(
            for: v2Schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let reloadCtx = ModelContext(reopened)
        let reloaded = try #require(
            try reloadCtx.fetch(FetchDescriptor<VittoraSchemaV2.SDTransaction>()).first { $0.id == txID }
        )
        #expect(reloaded.transferPairID == pairID)
    }

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

        do {
            let schema = Schema(VittoraSchemaV2.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(VittoraSchemaV2.SDTransaction(
                id: transferLegID,
                amount: 100,
                type: .transfer,
                transferPairID: pairID,
                externalID: UUID().uuidString
            ))
            ctx.insert(VittoraSchemaV2.SDTransaction(
                id: plainTxID,
                amount: 50,
                externalID: UUID().uuidString
            ))
            try ctx.save()
        }

        let schema = Schema(VittoraSchemaV2.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<VittoraSchemaV2.SDTransaction>())

        #expect(rows.count == 2)
        let reloadedLeg = rows.first { $0.id == transferLegID }
        let reloadedPlain = rows.first { $0.id == plainTxID }
        #expect(reloadedLeg?.amount == 100)
        #expect(reloadedLeg?.transferPairID == pairID)
        #expect(reloadedPlain?.amount == 50)
        #expect(reloadedPlain?.transferPairID == nil)
    }

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
            // V4's registered account class is the frozen snapshot (the live
            // SDAccount belongs to V6 only).
            ctx.insert(VittoraSchemaV4.SDAccount(id: withOpeningID, name: "Seeded", type: .bank, balance: 500, openingBalance: 1000))
            ctx.insert(VittoraSchemaV4.SDAccount(id: legacyID, name: "Legacy", type: .bank, balance: 500, openingBalance: nil))
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
        let rows = try ctx.fetch(FetchDescriptor<VittoraSchemaV4.SDAccount>())

        #expect(rows.count == 2)
        #expect(rows.first { $0.id == withOpeningID }?.openingBalance == 1000)
        #expect(rows.first { $0.id == legacyID }?.openingBalance == nil)
    }

    @Test("on-disk store round-trips debt linkedTransactionIDs")
    func onDiskStoreRoundTripsLinkedTransactionIDs() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-debt-links-roundtrip.store")

        let multiLinkID = UUID()
        let legacyLinkID = UUID()
        let legacyTxID = UUID()
        let tx1 = UUID()
        let tx2 = UUID()

        do {
            let schema = Schema(VittoraSchemaV5.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(SDDebt(
                id: multiLinkID,
                payeeID: UUID(),
                amount: 1000,
                direction: .lent,
                linkedTransactionIDs: [tx1, tx2]
            ))
            ctx.insert(SDDebt(
                id: legacyLinkID,
                payeeID: UUID(),
                amount: 500,
                direction: .borrowed,
                linkedTransactionID: legacyTxID
            ))
            try ctx.save()
        }

        let schema = Schema(VittoraSchemaV5.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDDebt>())

        #expect(rows.count == 2)
        let multiRow = try #require(rows.first { $0.id == multiLinkID })
        #expect(multiRow.linkedTransactionIDs == [tx1, tx2])
        #expect(multiRow.linkedTransactionIDsJSON != "[]")
        let legacyEntity = DebtMapper.toEntity(try #require(rows.first { $0.id == legacyLinkID }))
        #expect(legacyEntity.linkedTransactionIDs == [legacyTxID])
    }

    @Test("on-disk store round-trips account billing days")
    func onDiskStoreRoundTripsAccountBillingDays() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-account-billing-roundtrip.store")

        let accountID = UUID()

        do {
            let schema = Schema(VittoraSchemaV6.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            ctx.insert(SDAccount(
                id: accountID,
                name: "Visa",
                type: .creditCard,
                statementDayOfMonth: 5,
                dueDayOfMonth: 20
            ))
            try ctx.save()
        }

        let schema = Schema(VittoraSchemaV6.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let rows = try ctx.fetch(FetchDescriptor<SDAccount>())
        let row = try #require(rows.first { $0.id == accountID })

        #expect(row.statementDayOfMonth == 5)
        #expect(row.dueDayOfMonth == 20)
        let entity = AccountMapper.toEntity(row)
        #expect(entity.statementDayOfMonth == 5)
        #expect(entity.dueDayOfMonth == 20)
    }

    /// Regression for the "Duplicate version checksums detected" launch crash:
    /// a store created at the true V3 shape (pre-`openingBalance` account,
    /// pre-JSON debt) must stage-migrate V3→V6 on open. Before the schemas
    /// were frozen, V3–V6 aliased the live models, the on-disk store matched
    /// no version in the plan, and CoreData threw while building the stages.
    @Test("on-disk V3-era store stage-migrates to V6 preserving account and debt data")
    func onDiskStoreMigratesV3ToV6() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-v3-migration.store")

        let accountID = UUID()
        let debtID = UUID()
        let payeeID = UUID()
        let legacyLinkID = UUID()

        // Phase 1: seed at the frozen V3 shape (no migration plan).
        do {
            let v3Schema = Schema(VittoraSchemaV3.models)
            let config = ModelConfiguration(schema: v3Schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: v3Schema, configurations: [config])
            let ctx = ModelContext(container)
            ctx.insert(VittoraSchemaV1.SDAccount(
                id: accountID, name: "Legacy Checking", type: .bank, balance: 750
            ))
            let debt = VittoraSchemaV1.SDDebt(
                id: debtID, payeeID: payeeID, amount: 200, direction: .lent
            )
            debt.linkedTransactionID = legacyLinkID
            ctx.insert(debt)
            try ctx.save()
        }

        // Phase 2: reopen at V6 with the plan — runs stages V3→V4→V5→V6.
        let schema = Schema(VittoraSchemaV6.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)

        let account = try #require(
            try ctx.fetch(FetchDescriptor<SDAccount>()).first { $0.id == accountID }
        )
        #expect(account.name == "Legacy Checking")
        #expect(account.balance == 750)
        #expect(account.openingBalance == nil)       // added in V4, nil on legacy rows
        #expect(account.statementDayOfMonth == nil)  // added in V6
        #expect(account.dueDayOfMonth == nil)

        let debt = try #require(
            try ctx.fetch(FetchDescriptor<SDDebt>()).first { $0.id == debtID }
        )
        #expect(debt.amount == 200)
        #expect(debt.linkedTransactionID == legacyLinkID)
        // V5's JSON column arrives with its default on migrated rows.
        #expect(debt.linkedTransactionIDs.isEmpty)
    }
}
