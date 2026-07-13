import SwiftUI
import SwiftData
import VittoraCore

extension View {
    /// Shared environment injection for the main window and macOS Settings scene.
    @MainActor
    func vittoraAppEnvironments(
        appState: AppState,
        dependencies: DependencyContainer,
        settingsVM: SettingsViewModel,
        syncService: SyncStatusService,
        syncConflictHandler: SyncConflictHandler,
        modelContainer: ModelContainer
    ) -> some View {
        self
            .environment(appState)
            .environment(\.dependencies, dependencies)
            .environment(settingsVM)
            .environment(syncService)
            .environment(syncConflictHandler)
            .environment(\.currencyCode, settingsVM.selectedCurrencyCode)
            .environment(\.currencySymbol, String.currencySymbol(for: settingsVM.selectedCurrencyCode))
            .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
            .modelContainer(modelContainer)
            #if os(macOS)
            // macOS defaults every Form to the old "columns" style (labels in a
            // left gutter, controls clipped in sheets, sections as bare text).
            // Grouped matches the iOS look the app is designed around; the
            // style propagates through the environment to all Forms and sheets.
            .formStyle(.grouped)
            #endif
    }
}
