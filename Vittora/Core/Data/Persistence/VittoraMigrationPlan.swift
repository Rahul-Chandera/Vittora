import SwiftData

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
            SDDocument.self,
            SDDebt.self,
            SDSplitGroup.self,
            SDGroupExpense.self,
            SDTaxProfile.self,
            SDSavingsGoal.self,
        ]
    }
}

/// Schema V2 (DATAINTEGRITY-1): adds the optional `SDTransaction.transferPairID`
/// that links the two legs of a transfer. The change is purely additive (a new
/// optional attribute with no default required), so the V1→V2 step is a
/// CloudKit-safe lightweight migration.
enum VittoraSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        VittoraSchemaV1.models
    }
}

enum VittoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VittoraSchemaV1.self, VittoraSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: VittoraSchemaV1.self,
                toVersion: VittoraSchemaV2.self
            )
        ]
    }
}
