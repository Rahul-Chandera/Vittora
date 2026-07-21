import SwiftUI
import VittoraCore

/// WA1 proof UI: today's spend + budget remaining + last-updated footer.
struct WatchSnapshotView: View {
    @Bindable var store: WatchSnapshotStore
    @State private var isEnteringExpense = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = store.snapshot {
                    labeledAmount(
                        title: String(localized: "Today"),
                        amount: snapshot.todaySpend,
                        currencyCode: snapshot.currencyCode
                    )
                    labeledAmount(
                        title: String(localized: "Budget left"),
                        amount: snapshot.budgetRemaining,
                        currencyCode: snapshot.currencyCode
                    )
                    Text(lastUpdatedText(snapshot.generatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("watch-last-updated")
                    NavigationLink {
                        WatchRecentTransactionsView(store: store)
                    } label: {
                        Label(
                            String(localized: "Recent transactions"),
                            systemImage: "list.bullet"
                        )
                    }
                    .accessibilityIdentifier("watch-recent-transactions-link")

                    if let pending = store.pendingExpense {
                        pendingStatus(pending, currencyCode: snapshot.currencyCode)
                    } else {
                        Button(String(localized: "Add expense")) {
                            isEnteringExpense = true
                        }
                        .accessibilityHint(String(localized: "Enter an expense using the Digital Crown."))
                    }
                } else {
                    Text(String(localized: "Waiting for iPhone…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("watch-waiting")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .navigationTitle(String(localized: "Vittora"))
        .accessibilityIdentifier("watch-snapshot-root")
        .sheet(isPresented: $isEnteringExpense) {
            WatchQuickExpenseView(store: store)
        }
    }

    private func labeledAmount(title: String, amount: Decimal, currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: currencyCode))
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("watch-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    private func lastUpdatedText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: .now)
        return String(localized: "Updated \(relative)")
    }

    private func pendingStatus(_ expense: QueuedWatchExpense, currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(
                store.isPhoneReachable
                    ? String(localized: "Queued — syncing with iPhone…")
                    : String(localized: "Queued until iPhone reconnects"),
                systemImage: store.isPhoneReachable ? "arrow.triangle.2.circlepath" : "iphone.slash"
            )
            .font(.caption)
            Text(expense.amount, format: .currency(code: currencyCode))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            store.isPhoneReachable
                ? String(localized: "Expense is queued and syncing with iPhone")
                : String(localized: "Expense is queued until iPhone reconnects")
        )
        .accessibilityIdentifier("watch-pending-expense")
    }
}
