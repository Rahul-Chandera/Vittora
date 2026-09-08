import SwiftUI
import VittoraCore

struct GroupExpenseRowView: View {
    @Environment(\.currencyCode) private var currencyCode

    let expense: GroupExpense
    let payerName: String

    var body: some View {
        HStack(spacing: VSpacing.md) {
            // Icon
            RoundedRectangle(cornerRadius: 10)
                .fill(expense.isSettled ? VColors.secondaryGroupedBackground : VColors.primary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: expense.isSettled ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                        .font(.title3)
                        .foregroundStyle(expense.isSettled ? VColors.income : VColors.primaryOnSurface)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(VTypography.body)
                    .foregroundStyle(expense.isSettled ? VColors.textSecondary : VColors.textPrimary)
                    .strikethrough(expense.isSettled)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(payerName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "paid"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                    // Decorative separator: carries no information the adjacent
                    // labels don't already give, and VoiceOver should not read
                    // "middle dot". Hiding it also keeps the contrast sampler
                    // off a glyph too small to measure reliably.
                    Text("·")
                        .foregroundStyle(VColors.textPrimary)
                        .accessibilityHidden(true)
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                VAmountText(expense: expense.amount, size: .body)
                    .foregroundStyle(expense.isSettled ? VColors.textSecondary : VColors.textPrimary)

                Text(expense.splitMethod.displayName)
                    .font(VTypography.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(VColors.secondaryGroupedBackground)
                    .clipShape(Capsule())
                    .foregroundStyle(VColors.textPrimary)
            }
        }
        .padding(.vertical, VSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "\(expense.title), \(expense.amount.formatted(.currency(code: currencyCode))), paid by \(payerName), \(expense.splitMethod.displayName)"
            )
        )
        .accessibilityValue(expense.isSettled ? String(localized: "Settled") : String(localized: "Outstanding"))
    }
}
