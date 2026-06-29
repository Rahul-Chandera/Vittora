import SwiftUI
import SwiftData
import VittoraCore

/// Provides sample data for SwiftUI previews
@MainActor
enum PreviewSampleData {
    static var container: ModelContainer {
        do {
            return try ModelContainerConfig.makePreviewContainer()
        } catch {
            preconditionFailure("Failed to create preview container: \(error)")
        }
    }

    // Sample data factories will be added per module
}
