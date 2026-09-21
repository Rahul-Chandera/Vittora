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
        #expect(added(VittoraSchemaV7.self, VittoraSchemaV8.self) == [
            "SDTransaction.categorySuggestionRawValue",
        ])
        // V9 adds a whole entity rather than columns on an existing one, so every
        // property of SDInvestment is new.
        #expect(added(VittoraSchemaV8.self, VittoraSchemaV9.self) == [
            "SDInvestment.id",
            "SDInvestment.name",
            "SDInvestment.instrumentID",
            "SDInvestment.amount",
            "SDInvestment.sectionKey",
            "SDInvestment.startDate",
            "SDInvestment.maturityDate",
            "SDInvestment.remindsOnMaturity",
            "SDInvestment.note",
            "SDInvestment.createdAt",
            "SDInvestment.updatedAt",
        ])
    }

    /// Adding an entity must leave every existing entity untouched, or the stage is not
    /// lightweight and an upgrade rewrites rows it has no business rewriting.
    @Test("V9 changes no existing entity")
    func v9LeavesExistingEntitiesAlone() {
        let v8 = Set(Schema(VittoraSchemaV8.models).entities.map(\.name))
        let v9 = Set(Schema(VittoraSchemaV9.models).entities.map(\.name))

        #expect(v9.subtracting(v8) == ["SDInvestment"])
        #expect(v8.subtracting(v9).isEmpty)

        let v8Signature = signature(VittoraSchemaV8.self)
        let v9WithoutInvestment = signature(VittoraSchemaV9.self)
            .filter { !$0.hasPrefix("SDInvestment.") }
        #expect(v8Signature == Set(v9WithoutInvestment))
    }

    /// CloudKit rejects a new non-optional attribute that has no default: the
    /// mirrored record type cannot be evolved, and sync breaks for every existing
    /// user. Every attribute in the shipping schema must therefore be optional or
    /// carry a default.
    @Test("every attribute in the current schema is CloudKit-safe")
    func currentSchemaIsCloudKitSafe() {
        for entity in Schema(VittoraSchemaV9.models).entities {
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name) is non-optional with no default — CloudKit cannot evolve the record type, which breaks sync for existing users."
                )
            }
        }
    }

    /// The V8 column specifically: pinned separately so a later refactor that
    /// makes it non-optional fails here with an unmissable message.
    @Test("the V8 category-suggestion column is optional")
    func categorySuggestionColumnIsOptional() throws {
        let entity = try #require(
            Schema(VittoraSchemaV8.models).entities.first { $0.name == "SDTransaction" },
            "V8 must register SDTransaction"
        )
        let attribute = try #require(
            entity.attributes.first { $0.name == "categorySuggestionRawValue" },
            "V8 must add SDTransaction.categorySuggestionRawValue"
        )
        #expect(attribute.isOptional)
    }

    /// The container must register the newest schema, or a store written by the app is a
    /// version ahead of the plan that is meant to migrate it.
    @Test("the container ships the newest schema version")
    func containerShipsNewestSchema() throws {
        let newest = try #require(VittoraMigrationPlan.schemas.last)
        #expect(
            Set(Schema(ModelContainerConfig.allModels).entities.map(\.name))
                == Set(Schema(newest.models).entities.map(\.name))
        )
    }
}
