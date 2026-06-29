import SwiftUI

extension View {
    /// Presents new-transaction UI and switches to Settings when requested via `AppState`.
    func handlesAppCommands(
        appState: AppState,
        showAddTransaction: Binding<Bool>,
        onOpenSettings: (() -> Void)? = nil
    ) -> some View {
        self.onChange(of: appState.pendingCommand?.id) { _, _ in
            guard let request = appState.pendingCommand else { return }
            switch request.command {
            case .presentNewTransaction:
                showAddTransaction.wrappedValue = true
            case .openSettings:
                appState.selectedTab = .settings
                onOpenSettings?()
            }
            appState.clearPendingCommand()
        }
    }
}
