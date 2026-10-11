#if DEBUG
import CloudKit
import CoreData
import Foundation
import SwiftData
import VittoraCore

/// Release tool, Debug builds only: creates every synced record type, with
/// every field, in the CloudKit **Development** environment, so "Deploy Schema
/// Changes" can carry all of it to Production.
///
/// Development otherwise holds only what someone happened to save on a signed
/// build, and on 2026-10-04 that left Production missing three record types
/// and twelve fields that had already shipped. Run it through
/// `Scripts/cloudkit/init-development-schema.sh` before every Production deploy
/// (RELEASE_CHECKLIST §3). It prints `CKSCHEMA:` lines and exits — 0 only when
/// both the SwiftData and the household record types were written.
///
/// The SwiftData pass uses a scratch store in a temporary directory, so the
/// real ledger is never opened.
nonisolated enum CloudKitSchemaInitializer {
    static let launchArgument = "--initialize-cloudkit-schema"

    /// Never returns: the main thread parks in `dispatchMain()` while the work
    /// runs off it, and the process exits from there.
    static func runAndExit() -> Never {
        Task.detached {
            let swiftDataOK = initializeSwiftDataTypes()
            let householdOK = await initializeHouseholdTypes()
            exit(swiftDataOK && householdOK ? 0 : 1)
        }
        dispatchMain()
    }

    private static func initializeSwiftDataTypes() -> Bool {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: ModelContainerConfig.allModels) else {
            print("CKSCHEMA: FAILED — could not build the managed object model")
            return false
        }
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ckschema-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        } catch {
            print("CKSCHEMA: FAILED — scratch directory: \(error)")
            return false
        }
        let description = NSPersistentStoreDescription(url: storeDirectory.appendingPathComponent("ckschema.sqlite"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: HouseholdStore.containerIdentifier
        )
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "ckschema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("CKSCHEMA: FAILED — store load: \(loadError)")
            return false
        }
        do {
            try container.initializeCloudKitSchema(options: [])
            print("CKSCHEMA: OK — SwiftData: \(model.entities.compactMap(\.name).sorted().joined(separator: ", "))")
            return true
        } catch {
            print("CKSCHEMA: FAILED — SwiftData: \(error)")
            return false
        }
    }

    /// One of each household type with every field set. A field only reaches
    /// the schema if the saved record carries a value for it, so an optional
    /// left nil here would silently be missing from Production.
    /// `CloudKitSchemaInitializerTests` fails if one is.
    static let householdBudget = HouseholdBudget(
        id: "ckschema-budget", name: "Schema", amount: 1, currencyCode: "USD", createdAt: .now
    )
    static let householdExpense = HouseholdExpense(
        id: "ckschema-expense", budgetID: householdBudget.id, amount: 1, note: "Schema",
        date: .now, memberID: "ckschema", memberName: "Schema"
    )

    /// The household types are raw CloudKit records, not SwiftData, so
    /// `initializeCloudKitSchema` cannot see them. Save one of each through the
    /// app's own `makeRecord` in a scratch zone, then delete the zone; the
    /// record types and fields stay in the schema.
    private static func initializeHouseholdTypes() async -> Bool {
        let database = CKContainer(identifier: HouseholdStore.containerIdentifier).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "ckschema-\(UUID().uuidString)", ownerName: CKCurrentUserDefaultName)
        let records = [householdBudget.makeRecord(in: zoneID), householdExpense.makeRecord(in: zoneID)]
        do {
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        } catch {
            print("CKSCHEMA: FAILED — household zone: \(error)")
            return false
        }
        var succeeded = false
        do {
            let result = try await database.modifyRecords(saving: records, deleting: [])
            succeeded = true
            for (id, outcome) in result.saveResults {
                if case .failure(let error) = outcome {
                    print("CKSCHEMA: FAILED — household \(id.recordName): \(error)")
                    succeeded = false
                }
            }
        } catch {
            print("CKSCHEMA: FAILED — household save: \(error)")
        }
        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
        } catch {
            // The schema is already written; a leftover scratch zone in
            // Development is only clutter.
            print("CKSCHEMA: WARNING — scratch zone \(zoneID.zoneName) not deleted: \(error)")
        }
        if succeeded {
            print("CKSCHEMA: OK — household: \(records.map(\.recordType).joined(separator: ", "))")
        }
        return succeeded
    }
}
#endif
