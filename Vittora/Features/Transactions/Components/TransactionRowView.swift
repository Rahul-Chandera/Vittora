import SwiftUI

struct TransactionRowView: View {
    let transaction: TransactionEntity
    var category: CategoryEntity?
    var showSelection: Bool = false
    var isSelected: Bool = false

    private let formattedAmount: String
    private let amountColor: Color
    private let formattedTimeText: String
    private let typeLabel: String
    private let accessibilityText: String
    private let rowAccessibilityIdentifier: String

    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 40

    init(
        transaction: TransactionEntity,
        category: CategoryEntity? = nil,
        currencyCode: String = CurrencyDefaults.code,
        showSelection: Bool = false,
        isSelected: Bool = false
    ) {
        self.transaction = transaction
        self.category = category
        self.showSelection = showSelection
        self.isSelected = isSelected

        formattedAmount = CurrencyFormatter.format(transaction.amount, currencyCode: currencyCode)
        amountColor = Self.color(for: transaction.type)
        formattedTimeText = transaction.date.formatted(date: .omitted, time: .shortened)
        typeLabel = transaction.type.displayName

        let note = transaction.note ?? String(localized: "Transaction")
        let cat = category.map { ", \($0.name)" } ?? ""
        var description = "\(note)\(cat), \(typeLabel), \(formattedTimeText), \(formattedAmount)"
        if showSelection {
            description += isSelected
                ? ", \(String(localized: "Selected"))"
                : ", \(String(localized: "Not selected"))"
        }
        accessibilityText = description
        rowAccessibilityIdentifier = Self.makeAccessibilityIdentifier(for: transaction)
    }

    var body: some View {
        HStack(spacing: VSpacing.md) {
            if showSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(isSelected ? VColors.primary : VColors.textTertiary)
                    .accessibilityHidden(true)
            }

            ZStack {
                Circle()
                    .fill(
                        Color(hex: category?.colorHex ?? "#007AFF") ?? .blue
                    )
                    .frame(width: categoryIconSize, height: categoryIconSize)

                Image(systemName: category?.icon ?? "circle")
                    .font(.body)
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

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

                    Text(formattedTimeText)
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xs) {
                Text(formattedAmount)
                    .font(VTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(amountColor)

                Text(typeLabel)
                    .font(VTypography.caption2)
                    .foregroundColor(amountColor)
                    .opacity(0.7)
            }
        }
        .padding(VSpacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(rowAccessibilityIdentifier)
    }

    private static func color(for type: TransactionType) -> Color {
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

    private static func makeAccessibilityIdentifier(for transaction: TransactionEntity) -> String {
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
