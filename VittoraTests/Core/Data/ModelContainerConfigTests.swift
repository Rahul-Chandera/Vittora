import Testing
import SwiftData
import Foundation
@testable import Vittora

/// Pre-production: one schema snapshot only — no `SchemaMigrationPlan`.
@Suite("ModelContainer (schema V1)")
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
}
