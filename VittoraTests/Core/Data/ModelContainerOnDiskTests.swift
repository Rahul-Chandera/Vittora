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

        // Opens the CURRENT schema, because this round-trips the live `SDTransaction`.
        // It used to open V4 back when V4 still aliased the live class; since V8 froze
        // the pre-V8 shape into `VittoraSchemaV7.SDTransaction`, V4 registers the
        // snapshot instead and inserting a live row here aborts the process with
        // "Failed to cast model VittoraCore.SDTransaction". The assertions below are
        // unchanged — only the schema the store is opened at.
        do {
            let schema = Schema(VittoraSchemaV8.models)
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

        let schema = Schema(VittoraSchemaV8.models)
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

    @Test("V6 categories migrate to default spending buckets without data loss")
    func onDiskStoreMigratesCategoryBuckets() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-category-bucket-migration.store")
        let rentID = UUID()
        let customID = UUID()

        do {
            let schema = Schema(VittoraSchemaV6.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.insert(VittoraSchemaV6.SDCategory(
                id: rentID,
                name: "Rent",
                icon: "house.fill",
                colorHex: "#123456",
                type: .expense,
                isDefault: true,
                sortOrder: 8
            ))
            context.insert(VittoraSchemaV6.SDCategory(
                id: customID,
                name: "Coffee",
                icon: "cup.and.saucer.fill",
                type: .expense
            ))
            try context.save()
        }

        let schema = Schema(VittoraSchemaV7.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let rows = try ModelContext(container).fetch(FetchDescriptor<SDCategory>())
        let rent = try #require(rows.first { $0.id == rentID })
        let custom = try #require(rows.first { $0.id == customID })

        #expect(rent.spendingBucket == .needs)
        #expect(custom.spendingBucket == .wants)
        #expect(rent.name == "Rent")
        #expect(rent.icon == "house.fill")
        #expect(rent.colorHex == "#123456")
        #expect(rent.isDefault)
        #expect(rent.sortOrder == 8)
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

    @Test("on-disk V6 savings goal migrates to V7 with emergency-fund flag")
    func onDiskStoreMigratesSavingsGoalFlag() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-v7-emergency-fund.store")
        let goalID = UUID()

        do {
            let schema = Schema(VittoraSchemaV6.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.insert(VittoraSchemaV6.SDSavingsGoal(
                id: goalID,
                name: "Legacy Goal",
                category: .emergency,
                targetAmount: 12_000,
                currentAmount: 4_000
            ))
            try context.save()
        }

        let schema = Schema(VittoraSchemaV7.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let context = ModelContext(container)
        let migrated = try #require(
            try context.fetch(FetchDescriptor<SDSavingsGoal>()).first { $0.id == goalID }
        )
        #expect(migrated.name == "Legacy Goal")
        #expect(migrated.currentAmount == 4_000)
        #expect(migrated.isEmergencyFund == false)

        migrated.isEmergencyFund = true
        try context.save()

        let reopened = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let reloadContext = ModelContext(reopened)
        let reloaded = try #require(
            try reloadContext.fetch(FetchDescriptor<SDSavingsGoal>()).first { $0.id == goalID }
        )
        #expect(reloaded.isEmergencyFund)
    }

    /// V7→V8 (M3.2 instrumentation). Seeds a populated V7 store, migrates it to V8,
    /// and asserts the pre-existing rows survive with `categorySuggestion == nil` —
    /// "not instrumented" — because historical rows are deliberately NOT backfilled.
    /// Then writes all three states and round-trips them through a reopen.
    @Test("on-disk V7 store migrates to V8 leaving legacy rows uninstrumented")
    func onDiskStoreMigratesV7ToV8() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-v7-to-v8.store")

        let legacyID = UUID()
        let accountID = UUID()
        let categoryID = UUID()
        let legacyAmount = Decimal(string: "125.50") ?? 0
        let seededAt = Date(timeIntervalSince1970: 1_700_000_000)
        let externalID = UUID().uuidString

        // Phase 1: a populated store at V7, opened WITHOUT the migration plan.
        do {
            let schema = Schema(VittoraSchemaV7.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.insert(VittoraSchemaV7.SDTransaction(
                id: legacyID,
                amount: legacyAmount,
                date: seededAt,
                note: "pre-V8 row",
                type: .expense,
                categoryID: categoryID,
                accountID: accountID,
                externalID: externalID
            ))
            try context.save()
        }

        // Phase 2: reopen at V8 — the lightweight V7→V8 stage runs on open.
        let schema = Schema(VittoraSchemaV8.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.count == 1)

        let migrated = try #require(rows.first { $0.id == legacyID })
        #expect(migrated.amount == legacyAmount)
        #expect(migrated.note == "pre-V8 row")
        #expect(migrated.date == seededAt)
        #expect(migrated.categoryID == categoryID)
        #expect(migrated.accountID == accountID)
        #expect(migrated.externalID == externalID)
        // Not backfilled: nil means "no data", never "no suggestion was made".
        #expect(migrated.categorySuggestionRawValue == nil)
        #expect(migrated.categorySuggestion == nil)

        // Phase 3: write all three states.
        let suggestedID = UUID()
        let acceptedID = UUID()
        let overriddenID = UUID()
        let silentID = UUID()
        let otherCategoryID = UUID()

        context.insert(SDTransaction(
            id: acceptedID, amount: 10, categoryID: suggestedID,
            accountID: accountID, categorySuggestion: .suggested(suggestedID),
            externalID: UUID().uuidString
        ))
        context.insert(SDTransaction(
            id: overriddenID, amount: 20, categoryID: otherCategoryID,
            accountID: accountID, categorySuggestion: .suggested(suggestedID),
            externalID: UUID().uuidString
        ))
        context.insert(SDTransaction(
            id: silentID, amount: 30, categoryID: otherCategoryID,
            accountID: accountID, categorySuggestion: .noSuggestion,
            externalID: UUID().uuidString
        ))
        try context.save()

        // Phase 4: reopen and confirm every state survived a real round-trip.
        let reopened = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let reloadContext = ModelContext(reopened)
        let reloaded = try reloadContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(reloaded.count == 4)

        let accepted = try #require(reloaded.first { $0.id == acceptedID })
        #expect(accepted.categorySuggestion == .suggested(suggestedID))
        #expect(accepted.categoryID == suggestedID) // accepted: suggestion == chosen

        let overridden = try #require(reloaded.first { $0.id == overriddenID })
        #expect(overridden.categorySuggestion == .suggested(suggestedID))
        #expect(overridden.categoryID == otherCategoryID) // overridden: the pair differs

        let silent = try #require(reloaded.first { $0.id == silentID })
        #expect(silent.categorySuggestion == .noSuggestion)
        #expect(silent.categorySuggestionRawValue == "")

        let legacy = try #require(reloaded.first { $0.id == legacyID })
        #expect(legacy.categorySuggestion == nil)
    }

    /// Full-chain guard for the V8 change. Adding the category-suggestion column to the
    /// live `SDTransaction` forced V3, V4, V5, V6 and V7 to stop aliasing that class and
    /// point at the frozen `VittoraSchemaV7.SDTransaction` instead — five versions
    /// repointed at once. If any of those is now mis-shaped, an old store matches no
    /// version in the plan and CoreData throws while building the stages, which is a
    /// launch crash on upgrade rather than a recoverable error. Seeding at the oldest
    /// shape and opening at the newest walks every stage, including the custom V6→V7.
    @Test("on-disk V1 store stage-migrates all the way to V8")
    func onDiskStoreMigratesV1ToV8() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("vittora-v1-to-v8.store")

        let txID = UUID()
        let accountID = UUID()
        let amount = Decimal(string: "42.75") ?? 0
        let seededAt = Date(timeIntervalSince1970: 1_600_000_000)

        // Phase 1: seed at the true V1 shape, with no migration plan.
        do {
            let schema = Schema(VittoraSchemaV1.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = ModelContext(container)
            ctx.insert(VittoraSchemaV1.SDTransaction(
                id: txID,
                amount: amount,
                date: seededAt,
                note: "V1-era row",
                type: .expense,
                accountID: accountID,
                externalID: UUID().uuidString
            ))
            try ctx.save()
        }

        // Phase 2: open at V8 — runs V1→V2→…→V7→V8 in one go.
        let schema = Schema(VittoraSchemaV8.models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: VittoraMigrationPlan.self,
            configurations: [config]
        )
        let ctx = ModelContext(container)
        let migrated = try #require(
            try ctx.fetch(FetchDescriptor<SDTransaction>()).first { $0.id == txID }
        )

        #expect(migrated.amount == amount)
        #expect(migrated.note == "V1-era row")
        #expect(migrated.date == seededAt)
        #expect(migrated.accountID == accountID)
        // Columns added along the way are all nil — nothing is backfilled.
        #expect(migrated.transferPairID == nil)
        #expect(migrated.transferDirection == nil)
        #expect(migrated.categorySuggestion == nil)
    }
}
