import Testing
import SwiftData
@testable import Vittora

/// Creates an in-memory model container for testing
@MainActor
func makeTestModelContainer() throws -> ModelContainer {
    try ModelContainerConfig.makeContainer(inMemory: true)
}

/// Creates a model context for testing
@MainActor
func makeTestModelContext() throws -> ModelContext {
    let container = try makeTestModelContainer()
    return container.mainContext
}
