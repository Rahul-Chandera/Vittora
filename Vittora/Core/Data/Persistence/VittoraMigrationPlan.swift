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

/// Schema V3 (DATAINTEGRITY-1, A3): adds the optional
/// `SDTransaction.transferDirectionRawValue` so each transfer leg's balance
/// effect is derivable from a single row (paired via `transferPairID`). Purely
/// additive (a new optional attribute, no default required), so the V2→V3 step
/// is a CloudKit-safe lightweight migration. Legacy transfer legs keep
/// `transferDirection == nil` and remain non-derivable.
enum VittoraSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        VittoraSchemaV2.models
    }
}

/// Schema V4 (DATAINTEGRITY-12, A7): adds the optional `SDAccount.openingBalance`
/// used by balance reconciliation. Purely additive (a new optional attribute,
/// no default required), so the V3→V4 step is a CloudKit-safe lightweight
/// migration. Legacy rows keep `openingBalance == nil`; reconciliation derives
/// the implied opening on read instead of pinning a baseline at migrate time.
///
/// NOTE (merge-order versioning): A3 (`transferDirection`) merged first and kept
/// V3; A7 (`openingBalance`) rebased onto that tip and took V4. The two additive
/// changes are independent — V3 touches `SDTransaction`, V4 touches `SDAccount`.
enum VittoraSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        VittoraSchemaV3.models
    }
}

enum VittoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VittoraSchemaV1.self, VittoraSchemaV2.self, VittoraSchemaV3.self, VittoraSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: VittoraSchemaV1.self,
                toVersion: VittoraSchemaV2.self
            ),
            .lightweight(
                fromVersion: VittoraSchemaV2.self,
                toVersion: VittoraSchemaV3.self
            ),
            .lightweight(
                fromVersion: VittoraSchemaV3.self,
                toVersion: VittoraSchemaV4.self
            )
        ]
    }
}
