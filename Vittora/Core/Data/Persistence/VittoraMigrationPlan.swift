import SwiftData

// MARK: - Shared model sets

private enum VittoraSchemaModels {
    /// Models unchanged across V1–V6 transaction migrations (non-transaction entities).
    static let sharedBaseline: [any PersistentModel.Type] = [
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

enum VittoraSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [VittoraSchemaV1.SDTransaction.self] + VittoraSchemaModels.sharedBaseline
    }
}

/// Schema V2 (DATAINTEGRITY-1): adds the optional `SDTransaction.transferPairID`
/// that links the two legs of a transfer. The change is purely additive (a new
/// optional attribute with no default required), so the V1→V2 step is a
/// CloudKit-safe lightweight migration.
enum VittoraSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [VittoraSchemaV2.SDTransaction.self] + VittoraSchemaModels.sharedBaseline
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
        [SDTransaction.self] + VittoraSchemaModels.sharedBaseline
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

/// Schema V5 (DATAINTEGRITY-7, A11): adds `SDDebt.linkedTransactionIDsJSON`
/// (JSON-encoded `[UUID]`, CloudKit-safe) so repeated partial settlements
/// retain every cash leg instead of overwriting a single `linkedTransactionID`.
/// Purely additive (new String column defaults to `"[]"`; legacy scalar kept for
/// read-side merge), so the V4→V5 step is a CloudKit-safe lightweight migration.
enum VittoraSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        VittoraSchemaV4.models
    }
}

/// Schema V6 (FUNCTIONAL-4, C4): adds optional `SDAccount.statementDayOfMonth` and
/// `SDAccount.dueDayOfMonth` for credit-card billing reminders. Purely additive
/// (new optional Int columns), so the V5→V6 step is a CloudKit-safe lightweight
/// migration.
enum VittoraSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        VittoraSchemaV5.models
    }
}

enum VittoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            VittoraSchemaV1.self,
            VittoraSchemaV2.self,
            VittoraSchemaV3.self,
            VittoraSchemaV4.self,
            VittoraSchemaV5.self,
            VittoraSchemaV6.self,
        ]
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
            ),
            .lightweight(
                fromVersion: VittoraSchemaV4.self,
                toVersion: VittoraSchemaV5.self
            ),
            .lightweight(
                fromVersion: VittoraSchemaV5.self,
                toVersion: VittoraSchemaV6.self
            ),
        ]
    }
}
