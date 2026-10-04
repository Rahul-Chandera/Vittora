import SwiftUI
import WatchKit
import VittoraCore

@main
struct VittoraWatchApp: App {
    @State private var snapshotStore = WatchStores.snapshot

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // Normally the dashboard. The other cases exist so the App
                // Store gallery script can reach the entry and recent screens:
                // simctl can screenshot a watch simulator but cannot tap it or
                // open a URL on it, so every watch capture was otherwise the
                // same dashboard. Rendering the requested screen as the root
                // rather than navigating to it keeps the capture deterministic
                // and leaves no half-animated push in the shot.
                switch WatchInitialScreen.fromLaunchArguments {
                case .dashboard:
                    WatchSnapshotView(store: snapshotStore)
                case .recent:
                    WatchRecentTransactionsView(store: snapshotStore)
                case .quickExpense:
                    WatchQuickExpenseView(store: snapshotStore)
                case .voice:
                    WatchVoiceExpenseView(store: snapshotStore, spoken: WatchInitialScreen.voiceTextFromLaunchArguments)
                }
            }
            .overlay {
                if let alert = snapshotStore.budgetAlert {
                    WatchBudgetAlertView(threshold: alert)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: snapshotStore.budgetAlert)
            .task {
                snapshotStore.activate()
                // Wait for WCSession activation before verification transfers.
                try? await Task.sleep(for: .seconds(3))
                enqueueVerificationExpenseIfNeeded()
            }
        }
    }

    /// WA1 verification only — real entry UI is WA2.
    private func enqueueVerificationExpenseIfNeeded() {
        let prefix = "--verify-enqueue-watch-expense="
        guard let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return
        }
        let amountRaw = String(raw.dropFirst(prefix.count))
        guard let amount = Decimal(string: amountRaw), amount > 0 else { return }
        snapshotStore.enqueueExpense(amount: amount, categoryID: nil)
    }
}

/// One store per process. The Siri intent (M2.6.2) queues through the same
/// instance the screens show, so an expense logged by voice appears as
/// pending on the dashboard straight away.
@MainActor
enum WatchStores {
    static let snapshot = WatchSnapshotStore { threshold in
        WKInterfaceDevice.current().play(threshold.hapticType)
    }
}

private extension BudgetAlertThreshold {
    var hapticType: WKHapticType {
        switch self {
        case .seventyFive: .directionUp
        case .ninety: .notification
        case .oneHundred: .failure
        }
    }
}
