import SwiftUI
import VittoraCore

struct RecentTransactionsList: View {
    @Environment(\.colorScheme) private var colorScheme

    let transactions: [TransactionEntity]
    let onSeeAll: () -> Void
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            HStack {
                Text(String(localized: "Recent Transactions"))
                    .font(VTypography.subheadline)
                    .foregroundColor(highContrastText)
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: VSpacing.xxs) {
                        Text(String(localized: "See All"))
                            .font(VTypography.bodyBold)
                            .foregroundColor(highContrastText)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(highContrastText)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "See all transactions"))
                .accessibilityHint(String(localized: "Opens the Transactions tab"))
            }

            if transactions.isEmpty {
                Text(String(localized: "No transactions yet"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
            } else {
                VStack(spacing: VSpacing.xs) {
                    ForEach(transactions) { transaction in
                        RecentTransactionRow(transaction: transaction) {
                            onSelect(transaction.id)
                        }
                        if transaction.id != transactions.last?.id {
                            Divider()
                                .padding(.leading, VSpacing.xl + VSpacing.md)
                        }
                    }
                }
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
            }
        }
    }

    private var highContrastText: Color {
        colorScheme == .dark ? .white : .black
    }
}

private struct RecentTransactionRow: View {
    let transaction: TransactionEntity
    let onTap: () -> Void
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: VSpacing.md) {
                Circle()
                    .fill(VColors.tertiaryBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: typeIcon(for: transaction.type))
                            .font(VTypography.caption1Bold)
                            .foregroundColor(highContrastText)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: VSpacing.xxs) {
                    Text(transaction.note ?? String(localized: "Transaction"))
                        .font(VTypography.bodyBold)
                        .foregroundColor(highContrastText)
                        .adaptiveLineLimit(1)
                        .accessibilityHidden(true)

                    Text(transaction.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(VTypography.bodyBold)
                        .foregroundColor(highContrastText)
                        .accessibilityIdentifier("dashboard-recent-date-\(transaction.id.uuidString)")
                        .accessibilityHidden(true)
                }

                Spacer()

                Text(CurrencyFormatter.formatSigned(transaction.amount, type: transaction.type, currencyCode: currencyCode))
                    .font(VTypography.amountCaption)
                    .foregroundColor(highContrastText)
                    .amountScaling()
                    .accessibilityHidden(true)
            }
            .padding(.vertical, VSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(String(localized: "Opens transaction details"))
    }

    private var rowAccessibilityLabel: String {
        let note = transaction.note ?? String(localized: "Transaction")
        let date = transaction.date.formatted(.dateTime.month(.abbreviated).day())
        let amount = CurrencyFormatter.formatSigned(
            transaction.amount,
            type: transaction.type,
            currencyCode: currencyCode
        )
        return "\(note), \(transaction.type.displayName), \(date), \(amount)"
    }

    private var highContrastText: Color {
        colorScheme == .dark ? .white : .black
    }

    private func typeIcon(for type: TransactionType) -> String {
        switch type {
        case .expense: return "arrow.up"
        case .income: return "arrow.down"
        case .transfer: return "arrow.left.arrow.right"
        case .adjustment: return "equal"
        }
    }
}

#Preview {
    RecentTransactionsList(
        transactions: [],
        onSeeAll: {},
        onSelect: { _ in }
    )
    .padding()
}
