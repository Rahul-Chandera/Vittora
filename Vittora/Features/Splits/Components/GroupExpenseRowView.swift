import SwiftUI

struct GroupExpenseRowView: View {
    let expense: GroupExpense
    let payerName: String

    var body: some View {
        HStack(spacing: VSpacing.md) {
            // Icon
            RoundedRectangle(cornerRadius: 10)
                .fill(expense.isSettled ? VColors.secondaryBackground : VColors.primary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: expense.isSettled ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                        .font(.title3)
                        .foregroundStyle(expense.isSettled ? VColors.income : VColors.primary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(VTypography.body)
                    .foregroundStyle(expense.isSettled ? VColors.textSecondary : VColors.textPrimary)
                    .strikethrough(expense.isSettled)

                HStack(spacing: 4) {
                    Text(payerName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.primary)
                    Text(String(localized: "paid"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text("·")
                        .foregroundStyle(VColors.textSecondary)
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
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
                    .background(VColors.secondaryBackground)
                    .clipShape(Capsule())
                    .foregroundStyle(VColors.textSecondary)
            }
        }
        .padding(.vertical, VSpacing.xs)
    }
}
