import SwiftUI

struct TransactionRowView: View {
    let transaction: TransactionEntity
    var category: CategoryEntity?
    var showSelection: Bool = false
    var isSelected: Bool = false
    @Environment(\.currencyCode) private var currencyCode

    var body: some View {
        HStack(spacing: VSpacing.md) {
            // Selection checkbox
            if showSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(isSelected ? VColors.primary : VColors.textTertiary)
            }

            // Category icon circle
            ZStack {
                Circle()
                    .fill(
                        Color(hex: category?.colorHex ?? "#007AFF") ?? .blue
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: category?.icon ?? "circle")
                    .font(.body)
                    .foregroundColor(.white)
            }

            // Transaction details
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(transaction.note ?? "Transaction")
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                    .adaptiveLineLimit(1)

                HStack(spacing: VSpacing.sm) {
                    if let categoryName = category?.name {
                        Text(categoryName)
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                    }

                    Text(formattedTime(transaction.date))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textTertiary)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: VSpacing.xs) {
                let amountColor = transactionColor(for: transaction.type)
                Text(formatAmount(transaction.amount))
                    .font(VTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(amountColor)

                Text(transaction.type.rawValue.capitalized)
                    .font(VTypography.caption2)
                    .foregroundColor(amountColor)
                    .opacity(0.7)
            }
        }
        .padding(VSpacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier(rowAccessibilityIdentifier)
    }

    private var accessibilityDescription: String {
        let note = transaction.note ?? String(localized: "Transaction")
        let amount = formatAmount(transaction.amount)
        let type = transaction.type.rawValue.capitalized
        let cat = category.map { ", \($0.name)" } ?? ""
        return "\(note)\(cat), \(type), \(amount)"
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func transactionColor(for type: TransactionType) -> Color {
        switch type {
        case .expense:
            return VColors.expense
        case .income:
            return VColors.income
        case .transfer:
            return VColors.transfer
        case .adjustment:
            return VColors.primary
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }

    private var rowAccessibilityIdentifier: String {
        let base = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let normalized = base
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if normalized.isEmpty {
            return "transaction-row-\(transaction.id.uuidString.lowercased())"
        }

        return "transaction-row-\(normalized)"
    }
}

#Preview {
    VStack {
        TransactionRowView(
            transaction: TransactionEntity(
                amount: 25.50,
                note: "Coffee",
                type: .expense,
                paymentMethod: .cash
            ),
            category: CategoryEntity(
                name: "Food",
                icon: "fork.knife",
                colorHex: "#FF9500"
            )
        )

        TransactionRowView(
            transaction: TransactionEntity(
                amount: 1500.00,
                note: "Salary",
                type: .income,
                paymentMethod: .bankTransfer
            ),
            category: CategoryEntity(
                name: "Income",
                icon: "banknote",
                colorHex: "#34C759"
            ),
            showSelection: true,
            isSelected: true
        )
    }
    .padding(VSpacing.md)
    .background(VColors.background)
}
