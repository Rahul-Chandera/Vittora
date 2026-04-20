import Testing
import SwiftData
import Foundation
@testable import Vittora

@Suite("VittoraMigrationPlan Tests")
@MainActor
struct VittoraMigrationPlanTests {

    // MARK: - Plan Structure

    @Suite("Plan structure")
    @MainActor
    struct PlanStructureTests {

        @Test("plan has three schemas in ascending version order")
        func planHasThreeSchemas() {
            let schemas = VittoraMigrationPlan.schemas
            #expect(schemas.count == 3)
            #expect(VittoraSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
            #expect(VittoraSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
            #expect(VittoraSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
        }

        @Test("plan has exactly two migration stages")
        func planHasTwoStages() {
            #expect(VittoraMigrationPlan.stages.count == 2)
        }

        @Test("V1 schema registers twelve model types")
        func v1RegistersTwelveModels() {
            #expect(VittoraSchemaV1.models.count == 12)
        }

        @Test("V2 and V3 schemas register twelve model types")
        func v2v3RegistersTwelveModels() {
            #expect(VittoraSchemaV2.models.count == 12)
            #expect(VittoraSchemaV3.models.count == 12)
        }
    }

    // MARK: - V1 SDDocument Shape

    @Suite("V1 SDDocument shape")
    @MainActor
    struct V1DocumentShapeTests {

        @Test("V1 SDDocument exposes blob properties absent in V3")
        func v1DocumentHasBlobProperties() {
            let doc = VittoraSchemaV1.SDDocument()
            doc.thumbnailData = Data("thumb".utf8)
            doc.fileData = Data("file".utf8)
            doc.encryptedData = Data("enc".utf8)
            #expect(doc.thumbnailData == Data("thumb".utf8))
            #expect(doc.fileData == Data("file".utf8))
            #expect(doc.encryptedData == Data("enc".utf8))
        }

        @Test("V1 SDDocument defaults are valid")
        func v1DocumentDefaults() {
            let doc = VittoraSchemaV1.SDDocument()
            #expect(doc.fileName == "")
            #expect(doc.mimeType == "image/jpeg")
            #expect(doc.thumbnailData == nil)
            #expect(doc.fileData == nil)
            #expect(doc.encryptedData == nil)
        }
    }

    // MARK: - V1 → V3 File Migration

    @Suite("V1→V3 file migration")
    @MainActor
    struct FileMigrationTests {

        private func makeV1Store(at storeURL: URL, docID: UUID, fileName: String, thumbData: Data?) throws {
            let schema = Schema(VittoraSchemaV1.models)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = ModelContext(container)
            let doc = VittoraSchemaV1.SDDocument()
            doc.id = docID
            doc.fileName = fileName
            doc.thumbnailData = thumbData
            doc.fileData = thumbData.map { _ in Data("file_bytes".utf8) }
            ctx.insert(doc)
            try ctx.save()
        }

        @Test("migrating V1 store to V3 preserves document identity")
        func v1ToV3PreservesDocumentIdentity() throws {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("vittora_mig_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storeURL = tempDir.appendingPathComponent("store.sqlite")
            let docID = UUID()

            try makeV1Store(
                at: storeURL,
                docID: docID,
                fileName: "receipt.jpg",
                thumbData: Data("thumbnail_bytes".utf8)
            )

            // Open via migration plan (V1→V2→V3)
            let currentSchema = Schema(ModelContainerConfig.allModels)
            let migratedConfig = ModelConfiguration(
                schema: currentSchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let migratedContainer = try ModelContainer(
                for: currentSchema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [migratedConfig]
            )
            let ctx = ModelContext(migratedContainer)

            var descriptor = FetchDescriptor<SDDocument>(
                predicate: #Predicate { $0.id == docID }
            )
            descriptor.fetchLimit = 1
            let docs = try ctx.fetch(descriptor)
            #expect(docs.count == 1, "document must survive V1→V3 migration")
            #expect(docs.first?.fileName == "receipt.jpg")
            #expect(docs.first?.mimeType == "image/jpeg")

            // willMigrate wrote the thumbnail to the app's documents directory
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let thumbURL = docsDir.appendingPathComponent("\(docID.uuidString)_thumb.jpg")
            #expect(FileManager.default.fileExists(atPath: thumbURL.path),
                    "thumbnail file must be written to documents directory during willMigrate")
            try? FileManager.default.removeItem(at: thumbURL)
        }

        @Test("migrating V1 store with no blob data preserves document")
        func v1ToV3NoBlobData() throws {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("vittora_mig_noblob_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storeURL = tempDir.appendingPathComponent("store.sqlite")
            let docID = UUID()

            try makeV1Store(at: storeURL, docID: docID, fileName: "plain.pdf", thumbData: nil)

            let currentSchema = Schema(ModelContainerConfig.allModels)
            let config = ModelConfiguration(
                schema: currentSchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: currentSchema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)

            let docs = try ctx.fetch(FetchDescriptor<SDDocument>())
            #expect(docs.count == 1, "document with no blobs must survive migration")
            #expect(docs.first?.fileName == "plain.pdf")
        }

        @Test("migrating V1 store with multiple documents preserves all records")
        func v1ToV3MultipleDocuments() throws {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("vittora_mig_multi_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storeURL = tempDir.appendingPathComponent("store.sqlite")
            var docIDs: [UUID] = []

            // Create V1 store with 3 documents
            do {
                let schema = Schema(VittoraSchemaV1.models)
                let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [config])
                let ctx = ModelContext(container)
                for i in 1...3 {
                    let doc = VittoraSchemaV1.SDDocument()
                    doc.id = UUID()
                    doc.fileName = "doc_\(i).jpg"
                    doc.thumbnailData = i == 2 ? nil : Data("thumb_\(i)".utf8)
                    ctx.insert(doc)
                    docIDs.append(doc.id)
                }
                try ctx.save()
            }

            let currentSchema = Schema(ModelContainerConfig.allModels)
            let config = ModelConfiguration(
                schema: currentSchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: currentSchema,
                migrationPlan: VittoraMigrationPlan.self,
                configurations: [config]
            )
            let ctx = ModelContext(container)
            let all = try ctx.fetch(FetchDescriptor<SDDocument>())
            #expect(all.count == 3, "all 3 documents must survive migration")

            // Cleanup thumbnail side-effect files
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            for id in docIDs {
                try? FileManager.default.removeItem(
                    at: docsDir.appendingPathComponent("\(id.uuidString)_thumb.jpg")
                )
            }
        }
    }

    // MARK: - Current Schema (V3)

    @Suite("Current schema (V3)")
    @MainActor
    struct CurrentSchemaTests {

        @Test("in-memory V3 container supports all registered model types")
        func inMemoryContainerSupportsAllModels() throws {
            let container = try ModelContainerConfig.makeContainer(inMemory: true)
            #expect(container.configurations.isEmpty == false)
            let ctx = ModelContext(container)
            let tx = SDTransaction(amount: 42, externalID: UUID().uuidString)
            ctx.insert(tx)
            try ctx.save()
            let txs = try ctx.fetch(FetchDescriptor<SDTransaction>())
            #expect(txs.count == 1)
            #expect(txs.first?.amount == 42)
        }

        @Test("V3 SDDocument has no blob columns")
        func v3DocumentHasNoBlobColumns() {
            let doc = SDDocument()
            #expect(doc.fileName == "")
            #expect(doc.mimeType == "image/jpeg")
            #expect(doc.transactionID == nil)
        }
    }
}
