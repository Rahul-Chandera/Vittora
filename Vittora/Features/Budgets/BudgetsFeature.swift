import SwiftUI

/// Main entry point for the Budgets feature module.
/// Provides the primary list view for budget management.
public struct BudgetsFeature: View {
    public init() {}

    public var body: some View {
        BudgetListView()
    }
}

#Preview {
    BudgetsFeature()
        .environment(\.dependencies, DependencyContainer())
}
