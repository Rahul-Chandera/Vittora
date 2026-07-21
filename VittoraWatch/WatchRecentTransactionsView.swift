import SwiftUI
import VittoraCore

struct WatchRecentTransactionsView: View {
    @Bindable var store: WatchSnapshotStore

    var body: some View {
        Group {
            if let snapshot = store.snapshot, !snapshot.recentTransactions.isEmpty {
                List(snapshot.recentTransactions) { transaction in
                    WatchRecentTransactionRow(
                        transaction: transaction,
                        currencyCode: snapshot.currencyCode
                    )
                }
            } else {
                ContentUnavailableView(
                    String(localized: "No recent transactions"),
                    systemImage: "list.bullet"
                )
            }
        }
        .navigationTitle(String(localized: "Recent"))
        .accessibilityIdentifier("watch-recent-transactions")
    }
}

private struct WatchRecentTransactionRow: View {
    let transaction: WatchSnapshotTransaction
    let currencyCode: String

    private var signedAmount: Decimal {
        transaction.type == .expense ? -transaction.amount : transaction.amount
    }

    private var amountColor: Color {
        switch transaction.type {
        case .expense: .red
        case .income: .green
        case .transfer, .adjustment: .primary
        }
    }

    private var formattedAmount: String {
        let formatted = signedAmount.formatted(.currency(code: currencyCode))
        return transaction.type == .income ? "+\(formatted)" : formatted
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: transaction.categoryIcon)
                .frame(width: 20)
                .foregroundStyle(amountColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(.body)
                    .lineLimit(1)
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text(formattedAmount)
                .font(.caption.weight(.semibold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "\(transaction.name), \(transaction.type.displayName), \(formattedAmount), \(relativeDate)"
            )
        )
        .accessibilityIdentifier("watch-recent-transaction-\(transaction.id.uuidString)")
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: transaction.date, relativeTo: .now)
    }
}
