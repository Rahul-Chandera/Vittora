import SwiftUI
import WatchKit
import VittoraCore

@main
struct VittoraWatchApp: App {
    @State private var snapshotStore = WatchSnapshotStore { threshold in
        WKInterfaceDevice.current().play(threshold.hapticType)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchSnapshotView(store: snapshotStore)
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

private extension BudgetAlertThreshold {
    var hapticType: WKHapticType {
        switch self {
        case .seventyFive: .directionUp
        case .ninety: .notification
        case .oneHundred: .failure
        }
    }
}
