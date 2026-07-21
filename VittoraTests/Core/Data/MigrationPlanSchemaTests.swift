import Testing
import SwiftData
import Foundation
import VittoraCore
@testable import Vittora

/// Structural guards for `VittoraMigrationPlan`. CoreData aborts staged
/// migration with "Duplicate version checksums detected" (a launch crash on
/// any store upgrade) if two versioned schemas are structurally identical —
/// which happens when a VersionedSchema aliases live model classes instead of
/// frozen snapshots. These run in the regular CI unit batch.
@Suite("VittoraMigrationPlan schema distinctness")
@MainActor
struct MigrationPlanSchemaTests {

    /// "Entity.property" signature set for one versioned schema.
    private func signature(_ schema: any VersionedSchema.Type) -> Set<String> {
        var signature: Set<String> = []
        for entity in Schema(schema.models).entities {
            for property in entity.properties {
                signature.insert("\(entity.name).\(property.name)")
            }
        }
        return signature
    }

    @Test("every schema version is structurally distinct from every other")
    func allVersionsPairwiseDistinct() {
        let schemas = VittoraMigrationPlan.schemas
        let signatures = schemas.map { signature($0) }

        for i in schemas.indices {
            for j in schemas.indices where j > i {
                #expect(
                    signatures[i] != signatures[j],
                    "\(schemas[i]) and \(schemas[j]) have identical model shapes — a versioned schema is aliasing live models instead of frozen snapshots, which crashes staged migration with 'Duplicate version checksums detected'."
                )
            }
        }
    }

    @Test("each version adds exactly its documented columns")
    func versionsAddDocumentedColumns() {
        func added(_ from: any VersionedSchema.Type, _ to: any VersionedSchema.Type) -> Set<String> {
            signature(to).subtracting(signature(from))
        }

        #expect(added(VittoraSchemaV1.self, VittoraSchemaV2.self) == ["SDTransaction.transferPairID"])
        #expect(added(VittoraSchemaV2.self, VittoraSchemaV3.self) == ["SDTransaction.transferDirectionRawValue"])
        #expect(added(VittoraSchemaV3.self, VittoraSchemaV4.self) == ["SDAccount.openingBalance"])
        #expect(added(VittoraSchemaV4.self, VittoraSchemaV5.self) == ["SDDebt.linkedTransactionIDsJSON"])
        #expect(added(VittoraSchemaV5.self, VittoraSchemaV6.self) == [
            "SDAccount.statementDayOfMonth",
            "SDAccount.dueDayOfMonth",
        ])
        #expect(added(VittoraSchemaV6.self, VittoraSchemaV7.self) == [
            "SDCategory.spendingBucketRawValue",
            "SDSavingsGoal.isEmergencyFund",
        ])
    }
}
