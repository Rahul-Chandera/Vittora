import SwiftUI
import VittoraCore

/// Modal destinations for add/quick-entry flows (⌘N, floating +, deep links).
enum PresentedQuickAdd: Identifiable, Equatable {
    case quickEntry
    case destination(QuickAddDeepLink.Destination)

    var id: String {
        switch self {
        case .quickEntry:
            return "quickEntry"
        case .destination(let destination):
            return "destination-\(destination.rawValue)"
        }
    }
}

extension View {
    /// Presents new-transaction UI and routes settings / tab commands through `AppState`.
    func handlesAppCommands(
        appState: AppState,
        presentedQuickAdd: Binding<PresentedQuickAdd?>
    ) -> some View {
        modifier(AppCommandHandlingModifier(
            appState: appState,
            presentedQuickAdd: presentedQuickAdd
        ))
    }
}

private struct AppCommandHandlingModifier: ViewModifier {
    @Bindable var appState: AppState
    @Binding var presentedQuickAdd: PresentedQuickAdd?
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    func body(content: Content) -> some View {
        content
            .onAppear {
                consumePendingQuickAddIfNeeded()
            }
            .onChange(of: appState.pendingQuickAdd) { _, _ in
                consumePendingQuickAddIfNeeded()
            }
            .onChange(of: appState.pendingCommand?.id) { _, _ in
                guard let request = appState.pendingCommand else { return }
                switch request.command {
                case .presentNewTransaction:
                    presentedQuickAdd = .quickEntry
                case .presentQuickAdd(let destination):
                    presentedQuickAdd = .destination(destination)
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

    private func consumePendingQuickAddIfNeeded() {
        guard let destination = appState.pendingQuickAdd else { return }
        presentedQuickAdd = .destination(destination)
        appState.clearPendingQuickAdd()
        // Drop a duplicate command if openFromURL also requested one.
        if case .presentQuickAdd = appState.pendingCommand?.command {
            appState.clearPendingCommand()
        }
    }
}

extension View {
    /// The sheet for quick-add and typed deep-link destinations.
    ///
    /// A sheet at every width. On iPhone Duo the horizontal size class flips each
    /// time the device folds or unfolds; choosing a sheet or a full-screen cover
    /// from it — in an if/else around this whole view — rebuilt the tree and
    /// dismissed a form someone was halfway through. Swipe-to-dismiss is off for
    /// the same reason: every form here has a Cancel button.
    func quickAddPresentation(_ item: Binding<PresentedQuickAdd?>) -> some View {
        sheet(item: item) { presentation in
            quickAddContent(for: presentation)
                .interactiveDismissDisabled()
        }
    }
}

@ViewBuilder
private func quickAddContent(for presentation: PresentedQuickAdd) -> some View {
    switch presentation {
    case .quickEntry:
        QuickEntryView()
    case .destination(.expense):
        NavigationStack {
            TransactionFormView(initialType: .expense, showsCancelButton: true)
        }
    case .destination(.income):
        NavigationStack {
            TransactionFormView(initialType: .income, showsCancelButton: true)
        }
    case .destination(.transfer):
        NavigationStack {
            TransferFormView(showsCancelButton: true)
        }
    }
}
