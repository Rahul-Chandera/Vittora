import SwiftData
import Foundation

// MARK: - Schema V1 (initial production schema)

enum VittoraSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDPayee.self,
            SDRecurringRule.self,
            VittoraSchemaV1.SDDocument.self,
            SDDebt.self,
            SDSplitGroup.self,
            SDGroupExpense.self,
            SDTaxProfile.self,
            SDSavingsGoal.self,
        ]
    }

    /// Historical V1 shape of SDDocument — thumbnails and file data were stored as raw blobs.
    @Model final class SDDocument {
        var id: UUID = UUID()
        var fileName: String = ""
        var mimeType: String = "image/jpeg"
        var thumbnailData: Data?
        var fileData: Data?
        var encryptedData: Data?
        var transactionID: UUID?
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        init() {}
    }
}

// MARK: - Schema V2 (document blobs moved to filesystem)

enum VittoraSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDPayee.self,
            SDRecurringRule.self,
            SDDocument.self,
            SDDebt.self,
            SDSplitGroup.self,
            SDGroupExpense.self,
            SDTaxProfile.self,
            SDSavingsGoal.self,
        ]
    }
}

// MARK: - Schema V3 (unique id constraints + query indexes on all models)

enum VittoraSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDPayee.self,
            SDRecurringRule.self,
            SDDocument.self,
            SDDebt.self,
            SDSplitGroup.self,
            SDGroupExpense.self,
            SDTaxProfile.self,
            SDSavingsGoal.self,
        ]
    }
}

// MARK: - Migration plan

enum VittoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VittoraSchemaV1.self, VittoraSchemaV2.self, VittoraSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Moves thumbnail blobs from the SwiftData store to the filesystem before
    /// the schema upgrade drops the three blob columns. Files are written with
    /// .completeFileProtection so they are encrypted at rest by the OS.
    private static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: VittoraSchemaV1.self,
        toVersion: VittoraSchemaV2.self,
        willMigrate: { context in
            guard let documentsDir = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first
            else { return }

            let documents = try context.fetch(
                FetchDescriptor<VittoraSchemaV1.SDDocument>()
            )

            for doc in documents {
                guard let thumbData = doc.thumbnailData else { continue }
                let thumbURL = documentsDir
                    .appendingPathComponent("\(doc.id.uuidString)_thumb.jpg")
                try thumbData.write(to: thumbURL, options: .completeFileProtection)
                // Clear the blob so the column is empty before SwiftData drops it.
                doc.thumbnailData = nil
                doc.fileData = nil
                doc.encryptedData = nil
            }
            try context.save()
        },
        didMigrate: nil
    )

    private static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: VittoraSchemaV2.self,
        toVersion: VittoraSchemaV3.self
    )
}
