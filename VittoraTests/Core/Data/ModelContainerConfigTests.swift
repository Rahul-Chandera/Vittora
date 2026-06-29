import Testing
import SwiftData
import Foundation
import VittoraCore
@testable import Vittora

/// Fast in-memory schema checks — safe in the full CI unit-test batch.
@Suite("ModelContainer (versioned schema)")
@MainActor
struct ModelContainerConfigTests {

    @Test("in-memory container loads")
    func inMemoryContainerLoads() throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        #expect(container.configurations.isEmpty == false)
    }

    @Test("container allows insert and fetch")
    func insertAndFetch() throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let ctx = ModelContext(container)
        let tx = SDTransaction(amount: 42, externalID: UUID().uuidString)
        ctx.insert(tx)
        try ctx.save()
        let txs = try ctx.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.count == 1)
        #expect(txs.first?.amount == 42)
    }

    @Test("SDDocument matches current filesystem-backed shape")
    func sdDocumentShape() {
        let doc = SDDocument()
        #expect(doc.fileName == "")
        #expect(doc.mimeType == "image/jpeg")
        #expect(doc.transactionID == nil)
    }

    @Test("migration plan declares V1–V6 with lightweight stages")
    func migrationPlanShape() {
        #expect(VittoraMigrationPlan.schemas.count == 6)
        #expect(VittoraMigrationPlan.stages.count == 5)
        #expect(VittoraSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(VittoraSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(VittoraSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(VittoraSchemaV4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(VittoraSchemaV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(VittoraSchemaV6.versionIdentifier == Schema.Version(6, 0, 0))
    }

    @Test("schema snapshots differ between V1, V2, and V3")
    func schemaTransactionSnapshotsDifferByVersion() {
        #expect(VittoraSchemaV1.models.contains(where: { $0 == VittoraSchemaV1.SDTransaction.self }))
        #expect(VittoraSchemaV2.models.contains(where: { $0 == VittoraSchemaV2.SDTransaction.self }))
        #expect(VittoraSchemaV3.models.contains(where: { $0 == SDTransaction.self }))
        #expect(!VittoraSchemaV1.models.contains(where: { $0 == SDTransaction.self }))
        #expect(!VittoraSchemaV2.models.contains(where: { $0 == SDTransaction.self }))
    }
}
