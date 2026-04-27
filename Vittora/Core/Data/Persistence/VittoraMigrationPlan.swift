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

enum VittoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VittoraSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
