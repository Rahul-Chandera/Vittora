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
    }
}

extension View {
    /// Sheets / full-screen covers for quick-add and typed deep-link destinations.
    @ViewBuilder
    func quickAddPresentation(
        _ item: Binding<PresentedQuickAdd?>,
        asSheet: Bool
    ) -> some View {
        #if os(iOS)
        if asSheet {
            sheet(item: item) { presentation in
                quickAddContent(for: presentation)
            }
        } else {
            fullScreenCover(item: item) { presentation in
                quickAddContent(for: presentation)
            }
        }
        #else
        sheet(item: item) { presentation in
            quickAddContent(for: presentation)
        }
        #endif
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
