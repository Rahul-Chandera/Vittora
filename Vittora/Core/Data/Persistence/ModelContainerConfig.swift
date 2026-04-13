import SwiftData
import Foundation

enum ModelContainerConfig {
    /// All SwiftData model types registered in the app
    static var allModels: [any PersistentModel.Type] {
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
        ]
    }

    /// Create the shared model container
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container for previews and tests
    static func makePreviewContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }
}
