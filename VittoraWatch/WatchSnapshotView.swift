import SwiftUI
import VittoraCore

/// WA1 proof UI: today's spend + budget remaining + last-updated footer.
struct WatchSnapshotView: View {
    @Bindable var store: WatchSnapshotStore

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
}
