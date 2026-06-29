import SwiftUI
import VittoraCore

extension View {
    /// Presents new-transaction UI and routes settings / tab commands through `AppState`.
    func handlesAppCommands(
        appState: AppState,
        showAddTransaction: Binding<Bool>
    ) -> some View {
        modifier(AppCommandHandlingModifier(
            appState: appState,
            showAddTransaction: showAddTransaction
        ))
    }
}

private struct AppCommandHandlingModifier: ViewModifier {
    @Bindable var appState: AppState
    @Binding var showAddTransaction: Bool
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    func body(content: Content) -> some View {
        content.onChange(of: appState.pendingCommand?.id) { _, _ in
            guard let request = appState.pendingCommand else { return }
            switch request.command {
            case .presentNewTransaction:
                showAddTransaction = true
            case .openSettings:
                #if os(macOS)
                openSettings()
                #else
                appState.selectedTab = .settings
                #endif
            case .selectTab(let tab):
                appState.selectedTab = tab
            }
            appState.clearPendingCommand()
        }
    }
}
