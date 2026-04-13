import SwiftUI

struct RecentTransactionsList: View {
    let transactions: [TransactionEntity]
    let onSeeAll: () -> Void
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            HStack {
                Text(String(localized: "Recent Transactions"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Button(action: onSeeAll) {
                    Text(String(localized: "See All"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.primary)
                }
                .buttonStyle(.plain)
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
}

private struct RecentTransactionRow: View {
    let transaction: TransactionEntity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: VSpacing.md) {
                Circle()
                    .fill(typeColor(for: transaction.type).opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: typeIcon(for: transaction.type))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(typeColor(for: transaction.type))
                    }

                VStack(alignment: .leading, spacing: VSpacing.xxs) {
                    Text(transaction.note ?? String(localized: "Transaction"))
                        .font(VTypography.caption1Bold)
                        .foregroundColor(VColors.textPrimary)
                        .lineLimit(1)

                    Text(transaction.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                }

                Spacer()

                Text(formattedAmount(transaction.amount, type: transaction.type))
                    .font(VTypography.amountCaption)
                    .foregroundColor(typeColor(for: transaction.type))
            }
            .padding(.vertical, VSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func typeColor(for type: TransactionType) -> Color {
        switch type {
        case .expense: return VColors.expense
        case .income: return VColors.income
        case .transfer: return VColors.transfer
        case .adjustment: return VColors.primary
        }
    }

    private func typeIcon(for type: TransactionType) -> String {
        switch type {
        case .expense: return "arrow.up"
        case .income: return "arrow.down"
        case .transfer: return "arrow.left.arrow.right"
        case .adjustment: return "equal"
        }
    }

    private func formattedAmount(_ amount: Decimal, type: TransactionType) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
        switch type {
        case .expense: return "-\(formatted)"
        case .income: return "+\(formatted)"
        default: return formatted
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
